=begin
 Plugin: Fitbit
 Description: Grabs todays fitbit stats. See fitbit.com
 Author: Patrice Brend'amour

 Notes:
 1. To run this plugin you need to install the git version fitgem gem first. The easiest way to do this is to run the following commands:
     git clone https://github.com/whazzmaster/fitgem
     cd fitgem
     rake build
     sudo gem install pkg/fitgem-1.0.0.gem
 2. Afterwards you can aquire a valid Fitbit Consumer token: http://dev.fitbit.com if you want to use your own. A default one is provided.
 3. Upon first start, the plugin will ask you to open a URL and authorize the access to your data

=end


config = {
    'fitbit_description' => [
    'Grabs todays fitbit stats. See fitbit.com',
    'fitbit_unit_system defines the unit system used. Values: METRIC, US, UK.  (default is US)'],
    'fitbit_client_id' => '',
    'fitbit_client_secret' => '',
    'fitbit_refresh_token' => '',
    'fitbit_unit_system' => 'US',
    'fitbit_tags' => '#activities',
    'fitbit_log_water' => true,
    'fitbit_log_body_measurements' => true,
    'fitbit_log_sleep' => false,
    'fitbit_log_food' => false
}

$slog.register_plugin({ 'class' => 'FitbitLogger', 'config' => config })

require 'rubygems'
require 'fitgem'
require 'time'

class FitbitLogger < Slogger
    def do_log
        if @config.key?(self.class.name)
            config = @config[self.class.name]

            # Check that the user has configured the plugin
            if !config.key?('fitbit_client_id') || config['fitbit_client_secret'] == ""
                @log.warn("Fitbit has not been configured, please create an application at http://dev.fitbit.com.")
                return
            end
            else
            @log.warn("Fitbit has not been configured please edit your slogger_config file.")
            return
        end

        # ============================================================
        # Init fitgem client

        refresh_token = config['fitbit_refresh_token']
        fitbit_client_id = config['fitbit_client_id']
        fitbit_client_secret = config['fitbit_client_secret']
        redirect_uri = 'https://localhost:3000'
        token_url = 'https://api.fitbit.com/oauth2/token'
        auth_url = "https://www.fitbit.com/oauth2/authorize?response_type=code&client_id=#{fitbit_client_id}&redirect_uri=#{redirect_uri}&scope=activity%20heartrate%20location%20nutrition%20profile%20settings%20sleep%20social%20weight&expires_in=604800"
        developMode = $options[:develop]


        # ============================================================
        # request oauth token if needed
        if  !refresh_token.nil? && !refresh_token.empty?
          uri = URI.parse(token_url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          request = Net::HTTP::Post.new(uri.request_uri)
          request.basic_auth(fitbit_client_id, fitbit_client_secret)
          request['Content-Type'] = 'application/x-www-form-urlencoded'
          request.set_form_data(
            'grant_type' => 'refresh_token',
            'refresh_token' => refresh_token)
          response = http.request(request)
          response_json = JSON.parse(response.body)
          config['fitbit_refresh_token'] = response_json['refresh_token']
          access_token = response_json['access_token']
        else
          @log.info('Fitbit requires configuration, please run from the command line and follow the prompts')
          puts
          puts 'Slogger will now open an authorization page in your default web browser. Copy the code located in the URL and return here.'
          print 'Press Enter to continue...'
          gets
          `open '#{auth_url}'`
          print 'Paste the code you received here: '
          code = gets.strip
          uri = URI.parse(token_url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          request = Net::HTTP::Post.new(uri.request_uri)
          request.basic_auth(fitbit_client_id, fitbit_client_secret)
          request['Content-Type'] = 'application/x-www-form-urlencoded'
          request.set_form_data(
            'clientId' => fitbit_client_id,
            'grant_type' => 'authorization_code',
            'redirect_uri' => redirect_uri,
            'code' => code)
          response = http.request(request)
          response_json = JSON.parse(response.body)
          refresh_token = response_json['refresh_token']
          config['fitbit_refresh_token'] = refresh_token
          access_token = response_json['access_token']
        end
        client = Fitgem::Client.new(:consumer_key => fitbit_client_id, :consumer_secret => fitbit_client_secret, :ssl => true, :unit_system => translateUnitSystem(config['fitbit_unit_system']), :token => access_token)
        # ============================================================
        # iterate over the days and create entries
        $i = 0
        days = $options[:timespan]
        until $i >= days  do
            currentDate = Time.now - ((60 * 60 * 24) * $i)
            timestring = currentDate.strftime('%F')

            @log.info("Logging Fitbit summary for #{timestring}")

            activities = client.activities_on_date(timestring)
            summary = activities['summary']
            steps = summary['steps']
            floors = summary['floors']
            distance = summary['distances'][0]['distance']
            distanceUnit = client.label_for_measurement(:distance, false)
            veryActiveMinutes = summary['veryActiveMinutes']
            caloriesOut = summary["caloriesOut"]
            foodsEaten = ""

            if config['fitbit_log_body_measurements']
                measurements = client.body_measurements_on_date(timestring)
                weight = measurements['body']['weight']
                bmi = measurements['body']['bmi']
                weightUnit = client.label_for_measurement(:weight, false)
            end
            if config['fitbit_log_water']
                water = client.water_on_date(timestring)
                waterSummary = water['summary']
                loggedWater = waterSummary['water']
                waterUnit = client.label_for_measurement(:liquids, false)
            end
            if config['fitbit_log_sleep']
                sleep = client.sleep_on_date(timestring)
                sleepSummary = sleep['summary']

                hoursInBed = sleepSummary['totalTimeInBed'] / 60
                minutesInBed = sleepSummary['totalTimeInBed'] - (hoursInBed * 60)
                timeInBed = "#{hoursInBed}h #{minutesInBed}min"

                hoursAsleep = sleepSummary['totalMinutesAsleep'] / 60
                minutesAsleep = sleepSummary['totalMinutesAsleep'] - (hoursAsleep * 60)
                timeAsleep = "#{hoursAsleep}h #{minutesAsleep}min"
            end

            if config['fitbit_log_food']
                foodData = client.foods_on_date(timestring)
                foods = foodData['foods']

                mealList = Hash.new
                foodsEaten = ""
                totalCalories = 0
                foods.each do |foodEntry|
                    food = foodEntry['loggedFood']
                    mealId = food['mealTypeId']
                    if !mealList.has_key?(mealId)
                        mealList[mealId] = Meal.new(translateMeal(mealId))
                    end
                    meal = mealList[mealId]
                    meal.addFood(food['name'],food['amount'],food['unit']['plural'],food['calories'])
                end
                mealList.each do |key,meal|
                    foodsEaten += meal.to_s
                    totalCalories += meal.calories
                end

            end

            if developMode
                @log.info("Steps: #{steps}")
                @log.info("Distance: #{distance} #{distanceUnit}")
                @log.info("Floors: #{floors}")
                @log.info("Very Active Minutes: #{veryActiveMinutes}")
                @log.info("Calories Out: #{caloriesOut}")
                @log.info("Weight: #{weight} #{weightUnit}")
                @log.info("BMI: #{bmi}")
                @log.info("Water Intake: #{loggedWater} #{waterUnit}")
                @log.info("Time In Bed: #{timeInBed}")
                @log.info("Time Asleep: #{timeAsleep}")
                @log.info("Foods Eaten:\n #{foodsEaten}")
            end

            tags = config['fitbit_tags'] || ''
            tags = "\n\n#{tags}\n" unless tags == ''

            output = "**Steps:** #{steps}\n**Floors:** #{floors}\n**Distance:** #{distance} #{distanceUnit}\n**Very Active Minutes:** #{veryActiveMinutes}\n**Calories Out:** #{caloriesOut}\n"

            if config['fitbit_log_body_measurements']
                output += "**Weight:** #{weight} #{weightUnit}\n**BMI:** #{bmi}\n"
            end
            if config['fitbit_log_water']
            	output += "**Water Intake:** #{loggedWater} #{waterUnit}\n"
            end
            if config['fitbit_log_sleep']
                output += "**Time In Bed:** #{timeInBed}\n"
                output += "**Time Asleep:** #{timeAsleep}\n"
            end
            if config['fitbit_log_food']
                output += "**Foods eaten:** #{totalCalories} calories\n#{foodsEaten}"
            end

            # Create a journal entry
            options = {}
            options['content'] = "## Fitbit - Summary for #{currentDate.strftime(@date_format)}\n\n#{output}#{tags}"
            options['datestamp'] = currentDate.utc.iso8601
            sl = DayOne.new
            sl.to_dayone(options)
            $i += 1
        end
        return config
    end

    def translateMeal(mealId)
        case mealId
        when 1
            return "Breakfast"
        when 2
            return "Morning Snack"
        when 3
            return "Lunch"
        when 4
            return "Afternoon Snack"
        when 5
            return "Dinner"
        else
            return "Anytime"
        end
    end

    def translateUnitSystem(unitSystemString)
        case unitSystemString
        when "US"
            return Fitgem::ApiUnitSystem.US
        when "METRIC"
            return Fitgem::ApiUnitSystem.METRIC
        when "UK"
            return Fitgem::ApiUnitSystem.UK
        else
            return Fitgem::ApiUnitSystem.US
        end
    end
end
class Meal
    def initialize(name)
        @name = name
        @foods = Array.new
        @calories = 0
    end
    def addFood(name, amount, unit, calories)
        @foods.push("#{name} (#{amount} #{unit}, #{calories} calories)")
        @calories += calories
    end

    def to_s
        mealString = " * #{@name}: #{@calories} calories\n"
        @foods.each do |food|
            mealString += "  * #{food}\n"
        end
        return mealString
    end

    def calories
        @calories
    end
end

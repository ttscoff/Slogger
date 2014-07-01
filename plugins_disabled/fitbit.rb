=begin
 Plugin: Fitbit
 Description: Grabs todays fitbit stats. See fitbit.com
 Author: Patrice Brend'amour
 
 Notes:
 1. To run this plugin you need to install the fitgem gem first:
 $ sudo gem install fitgem
 2. Afterwards you can aquire a valid Fitbit Consumer token: http://dev.fitbit.com if you want to use your own. A default one is provided.
 3. Upon first start, the plugin will ask you to open a URL and authorize the access to your data
 
=end


config = {
    'fitbit_description' => [
    'Grabs todays fitbit stats. See fitbit.com',
    'fitbit_unit_system defines the unit system used. Values: METRIC, US, UK.  (default is US)'],
    'fitbit_consumer_key' => 'f6ec3c9a6996485bbc20e8296f25c671',
    'fitbit_consumer_secret' => '0af53444fc28434fbc9a88f3cad84764',
    'fitbit_oauth_token' => '',
    'fitbit_oauth_secret' => '',
    'fitbit_unit_system' => 'US',
    'fitbit_tags' => '#social #activities',
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
            if !config.key?('fitbit_consumer_key') || config['fitbit_consumer_secret'] == ""
                @log.warn("Fitbit has not been configured, please create an application at http://dev.fitbit.com.")
                return
            end
            else
            @log.warn("Fitbit has not been configured please edit your slogger_config file.")
            return
        end
        
        # ============================================================
        # Init fitgem client
        
        oauth_token = config['fitbit_oauth_token']
        oauth_secret = config['fitbit_oauth_secret']
        fitbit_consumer_key = config['fitbit_consumer_key']
        fitbit_consumer_secret = config['fitbit_consumer_secret']
        
        client = Fitgem::Client.new(:consumer_key => fitbit_consumer_key, :consumer_secret => fitbit_consumer_secret, :ssl => true, :unit_system => translateUnitSystem(config['fitbit_unit_system']))
        developMode = $options[:develop]
        
        
        # ============================================================
        # request oauth token if needed
        @log.info("#{oauth_token}")
        if  !oauth_token.nil? && !oauth_secret.nil? && !oauth_token.empty? && !oauth_secret.empty?
            access_token = client.reconnect(oauth_token, oauth_secret)
        else
            request_token = client.request_token
            token = request_token.token
            secret = request_token.secret
            @log.info("Fitbit requires configuration, please run from the command line and follow the prompts")
            puts
            puts "------------- Fitbit Configuration --------------"
            puts "Slogger will now open an authorization page in your default web browser. Copy the code you receive and return here."
            print "Press Enter to continue..."
            gets
            %x{open "http://www.fitbit.com/oauth/authorize?oauth_token=#{token}"}
            print "Paste the code you received here: "
            verifier = gets.strip
            
            begin
                access_token = client.authorize(token, secret, { :oauth_verifier => verifier })
           
                if developMode
                    @log.info("Verifier is: "+verifier)
                    @log.info("Token is:    "+access_token.token)
                    @log.info("Secret is:   "+access_token.secret)
                end
                
                config['fitbit_oauth_token'] = access_token.token;
                config['fitbit_oauth_secret'] = access_token.secret
                @log.info("Fitbit successfully configured, run Slogger again to continue")
            rescue
                @log.error("Failed to authorize Fitbit. Please try again")
            end
            return config
        end
        
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
    


=begin
Plugin: Strava Logger
Description: Creates separate entries for rides and runs you finished today
Author: [Patrick Walsh](http://twitter.com/zmre)
Configuration:
  strava_access_token: "your access token"
  strava_tags: "#social #sports"
  strava_unit "metric" || "imperial"
Notes:
  - strava_access_token is an oauth access token for your account. You can obtain one at https://www.strava.com/settings/api
  - strava_tags are tags you want to add to every entry, e.g. "#social #sports #cycling #training"
  - strava_units determine what units to display data in: "metric" or "imperial"
=end

require 'rexml/document';

config = {
  'description' => ['strava_access_token is an oauth access token for your account. You can obtain one at https://www.strava.com/settings/api',
                    'strava_tags are tags you want to add to every entry, e.g. "#social #sports #cycling #training"',
                    'strava_units determine what units to display data in: "metric" or "imperial"'],
  'strava_access_token' => '',
  'strava_tags' => '#social #sports',
  'strava_unit' => 'metric'
}

$slog.register_plugin({ 'class' => 'StravaLogger', 'config' => config })

class StravaLogger < Slogger
  NOT_CONFIGURED = 'Strava has not been configured or is invalid, please edit your slogger_config file.'
  NO_ACCESS_TOKEN = 'Strava access token has not been configured, please edit your slogger_config file.'
  def do_log
    @grconfig = @config[self.class.name]
    return @log.warn(NOT_CONFIGURED) if @grconfig.nil?

    access_token = @grconfig['strava_access_token']
    return @log.warn(NO_ACCESS_TOKEN) if access_token.nil? || access_token.strip.empty?

    feed = "https://www.strava.com/api/v3/athlete/activities?access_token=#{access_token}"

    @log.info("Logging activities from Strava")

    retries = 0
    success = false

    until success
      if parse_feed(feed)
        success = true
      else
        break if $options[:max_retries] == retries
        retries += 1
        @log.error("Error parsing Strava feed, retrying (#{retries}/#{$options[:max_retries]})")
        sleep 2
      end

      unless success
        @log.fatal("Could not parse feed #{feed}")
      end
    end
  end

  def parse_feed(rss_feed)
    tags = @grconfig['strava_tags'] || ''
    tags = "\n\n#{tags}\n" unless tags == ''

    begin
      res = Net::HTTP.get_response(URI.parse(rss_feed))
    rescue Exception => e
      raise "ERROR retrieving Strava ride list url: #{rss_feed}"
    end

    return false if res.nil?

    begin
      JSON.parse(res.body)['rides'].each {|rides|
        @log.info("Examining ride #{rides['id']}: #{rides['name']}")

        begin
          res2 = Net::HTTP.get_response(URI.parse("http://www.strava.com/api/v1/rides/#{rides['id']}"));
        rescue Exception => e
          raise "ERROR retrieving Strava ride #{rides['id']}: http://www.strava.com/api/v1/rides/#{rides['id']}"
        end

        ride_json = JSON.parse(res2.body)
        @log.info("Parsed ride #{rides['id']}")
        strava = ride_json['ride']
        date = Time.parse(strava['startDate'])

        if date > @timespan
          movingTime = Integer(strava['movingTime'])
          movingTimeMM, movingTimeSS = movingTime.divmod(60)
          movingTimeHH, movingTimeMM = movingTimeMM.divmod(60)
          elapsedTime = Integer(strava['elapsedTime'])
          elapsedTimeMM, elapsedTimeSS = elapsedTime.divmod(60)
          elapsedTimeHH, elapsedTimeMM = elapsedTimeMM.divmod(60)

          if @grconfig['strava_unit'] == 'imperial'
            unit = ['ft', 'mi', 'mph']
            strava['distance'] *= 0.000621371 #mi
            strava['averageSpeed'] *= 2.23694 #mi
            strava['maximumSpeed'] *= 0.000621371 #mi
            strava['elevationGain'] *= 3.28084 #ft
          elsif @grconfig['strava_unit'] == 'metric'
            unit = ['m', 'km', 'kph']
            strava['distance'] *= 0.001001535 #km
            strava['averageSpeed'] *= 3.611940299 #km
            strava['maximumSpeed'] *= 0.001000553 #km
          end

          output = ''
          output += "# Strava Ride - %.2f %s - %dh %dm %ds - %.1f %s - %s\n\n" % [strava['distance'], unit[1], movingTimeHH, movingTimeMM, movingTimeSS, strava['averageSpeed'], unit[2], strava['name']] unless strava['name'].nil?
          output += "* **Description**: #{strava['description']}\n" unless strava['description'].nil?
          output += "* **Distance**: %.2f %s\n" % [strava['distance'], unit[1]] unless strava['distance'].nil?
          output += "* **Elevation Gain**: %d %s\n" % [strava['elevationGain'], unit[0]] unless strava['elevationGain'].nil?
          output += "* **Bike**: #{strava['bike']['name']}\n" unless strava['bike'].nil?
          output += "* **Average Speed**: %.1f %s\n" % [strava['averageSpeed'], unit[2]] unless strava['averageSpeed'].nil?
          output += "* **Max Speed**: %.1f %s\n" % [strava['maximumSpeed'], unit[2]] unless strava['maximumSpeed'].nil?
          output += "* **Location**: #{strava['location']}\n" unless strava['location'].nil?
          output += "* **Elapsed Time**: %02d:%02d:%02d\n" % [elapsedTimeHH, elapsedTimeMM, elapsedTimeSS] unless strava['elapsedTime'].nil?
          output += "* **Moving Time**: %02d:%02d:%02d\n" % [movingTimeHH, movingTimeMM, movingTimeSS] unless strava['movingTime'].nil?
          output += "* **Link**: http://app.strava.com/rides/#{rides['id']}\n\n"

          options = {}
          options['content'] = "#{output}\n\n#{tags}"
          options['datestamp'] = date.utc.iso8601
          options['starred'] = false
          options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip #TODO: turn location into a Day One location

          DayOne.new.to_dayone(options)
        else
          break
        end
      }
    rescue Exception => e
      @log.error("ERROR parsing Strava results from #{rss_feed}")
      raise e
    end

    return true
  end
end

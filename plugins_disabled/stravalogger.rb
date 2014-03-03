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

require 'open-uri'
require 'json'

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
      res = URI.parse(rss_feed).read
    rescue Exception => e
      raise "ERROR retrieving Strava activity list url: #{rss_feed} - #{e}"
    end

    return false if res.nil?

    begin
      JSON.parse(res).each {|activity|
        @log.info("Examining activity #{activity['id']}: #{activity['name']}")

        date = Time.parse(activity['start_date_local'])

        if date > @timespan
          moving_time = Integer(activity['moving_time'])
          moving_time_minutes, moving_time_seconds = moving_time.divmod(60)
          moving_time_hours, moving_time_minutes = moving_time_minutes.divmod(60)
          elapsed_time = Integer(activity['elapsed_time'])
          elapsed_time_minutes, elapsed_time_seconds = elapsed_time.divmod(60)
          elapsed_time_hours, elapsed_time_minutes = elapsed_time_minutes.divmod(60)

          if @grconfig['strava_unit'] == 'imperial'
            unit = ['ft', 'mi', 'mph']
            activity['distance'] *= 0.000621371 #mi
            activity['average_speed'] *= 2.23694 #mi
            activity['max_speed'] *= 0.000621371 #mi
            activity['total_elevation_gain'] *= 3.28084 #ft
          else
            unit = ['m', 'km', 'kph']
            activity['distance'] *= 0.001001535 #km
            activity['average_speed'] *= 3.611940299 #km
            activity['max_speed'] *= 0.001000553 #km
          end

          output = ''
          output += "# Strava Activity - %.2f %s - %dh %dm %ds - %.1f %s - %s\n\n" % [activity['distance'], unit[1], moving_time_hours, moving_time_minutes, moving_time_seconds, activity['average_speed'], unit[2], activity['name']] unless activity['name'].nil?
          output += "* **Description**: #{activity['description']}\n" unless activity['description'].nil?
          output += "* **Type**: #{activity['type']}\n" unless activity['type'].nil?
          output += "* **Distance**: %.2f %s\n" % [activity['distance'], unit[1]] unless activity['distance'].nil?
          output += "* **Elevation Gain**: %d %s\n" % [activity['total_elevation_gain'], unit[0]] unless activity['total_elevation_gain'].nil?
          output += "* **Average Speed**: %.1f %s\n" % [activity['average_speed'], unit[2]] unless activity['average_speed'].nil?
          output += "* **Max Speed**: %.1f %s\n" % [activity['max_speed'], unit[2]] unless activity['max_speed'].nil?
          #TODO: turn location into a Day One location
          output += "* **Location**: #{activity['location_city']}\n" unless activity['location_city'].nil?
          output += "* **Elapsed Time**: %02d:%02d:%02d\n" % [elapsed_time_hours, elapsed_time_minutes, elapsed_time_seconds] unless activity['elapsed_time'].nil?
          output += "* **Moving Time**: %02d:%02d:%02d\n" % [moving_time_hours, moving_time_minutes, moving_time_seconds] unless activity['moving_time'].nil?
          output += "* **Link**: http://www.strava.com/activities/#{activity['id']}\n"

          options = {}
          options['content'] = "#{output}#{tags}"
          options['datestamp'] = Time.parse(activity['start_date']).iso8601
          options['starred'] = false
          options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip 

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

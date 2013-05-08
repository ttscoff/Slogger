=begin
 Plugin: Runkeeper
 Description: Gets recent runkeeper data
 Author: Alan Schussman
 
 Notes:
   To run this plugin you need a Runkeeper API app ID and secret key, plus a user access_token that gets specified in the config. Some instructions for starting up with the Runkeeper API are at https://gist.github.com/ats/5538092. Structure is based heavily on Patrice Brend'amour's fitbit plugin. Provide a filename in runkeeper_save_dat_file to optionally dump the retrieved activity data into a tab-separated text file for playing with later.
 Configuration:
   runkeeper_access_token
   runkeeper_tags: '#activities #workout #runkeeper'
   runkeeper_save_data_file: '/home/users/username/data/runkeeper.txt'

=end


config = {
    'runkeeper_description' => [
    'Gets runkeeper activity information'],
    'runkeeper_access_token' => '',
    'runkeeper_tags' => '#activities #workout #runkeeper',
    'runkeeper_save_data_file' => '',
}

$slog.register_plugin({ 'class' => 'RunkeeperLogger', 'config' => config })

require 'rubygems'
require 'time'
require 'json'

class RunkeeperLogger < Slogger
    def do_log
        if @config.key?(self.class.name)
            config = @config[self.class.name]
            
            # Check that the user has configured the plugin
            if config['runkeeper_access_token'] == ""
                @log.warn("Runkeeper has not been configured; you need a developer API key to create a user access_token.")
                return
            end
            else
            @log.warn("Runkeeper has not been configured; please edit your slogger_config file.")
            return
        end
                
        rk_token = config['runkeeper_access_token']
        save_data_file = config['runkeeper_save_data_file']
        developMode = $options[:develop]
        

        # get activities array:
        #   This is currently limited and get the most recent 25 entries,
        # then identifies entries in the specified days range to include
        # in the Day One journal entries.

        activitiesReq = sprintf('curl https://api.runkeeper.com/fitnessActivities -s -X GET -H "Authorization: Bearer %s"', rk_token)
        activities = JSON.parse(`#{activitiesReq}`)
        
        # ============================================================
        # iterate over the days and create entries
        # All based on the fitbit plugin
        $i = 0
        days = $options[:timespan]
        until $i >= days  do
            currentDate = Time.now - ((60 * 60 * 24) * $i)
            timestring = currentDate.strftime('%F')
            
            @log.info("Logging Runkeeper summary for #{timestring}")
            
            output = ""
            activities["items"].each do | activity |
              if Date.parse(activity["start_time"]).to_s == timestring   # activity is in date range
                activityReq = sprintf('curl https://api.runkeeper.com%s -s -X GET -H "Authorization: Bearer %s"', activity["uri"], rk_token)
                active = JSON.parse(`#{activityReq}`)
                type = active["type"]
                distance = (active["total_distance"]/1609.34*100).round / 100.0
                duration = (active["duration"]/60*100).round / 100
                time = active["start_time"]
                notes = active["notes"]
                equipment = active["equipment"]
                if developMode
                  @log.info
                  @log.info("#{type}")
                  @log.info("#{distance}")
                  @log.info("#{duration}")
                  @log.info("#{time}")
                  @log.info("#{notes}")
                  @log.info("#{equipment}")
                end
                output = output + "\n\n### Activity: #{type}\n* **Time**: #{time}\n* **Distance**: #{distance} miles\n* **Duration**: #{duration} minutes\n"
                output = output + "* **Equipment**: #{equipment}\n" unless equipment == "None"
                output = output + "* **Notes**: #{notes}\n" unless notes.nil?
                
                # save to text file if desired for stats and stuff
                if save_data_file != ""
                  open(save_data_file, 'a') { |f|
                    f.puts("#{type}\t#{distance}\t#{duration}\t#{time}\t#{equipment}")
                  }
                end
              end
            end
            # Create a journal entry
            tags = config['runkeeper_tags'] || ''
            tags = "\n\n#{tags}\n" unless tags == ''

            options = {}
            options['content'] = "## Workouts and Exercise\n\n#{output}#{tags}"
            options['datestamp'] = currentDate.utc.iso8601
            
            sl = DayOne.new
            sl.to_dayone(options) unless output == ""

            $i += 1
        end
        return config
    end
end

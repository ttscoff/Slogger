=begin
Plugin: My New Logger
Description: Brief description (one line)
Author: [My Name](My URL)
Configuration:
  option_1_name: [ "example_value1" , "example_value2", ... ]
  option_2_name: example_value
Notes:
  - multi-line notes with additional description and information (optional)
=end

config = { # description and a primary key (username, url, etc.) required
  'description' => ['Logs your posts from Instagram',
                    'No real setup required beyond needing to authenticate with the Instagram API.',
                    'backdate (true/false) gives you the option to add the 20 most recent photos to Day One.'],
  'tags' => '#social #instagram', # A good idea to provide this with an appropriate default setting
  'backdate' => false,
  'access_token' => ''
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'InstagramLogger', 'config' => config })

require 'date'

class Time
    def to_datetime
    # Convert seconds + microseconds into a fractional number of seconds
    seconds = sec + Rational(usec, 10**6)

    # Convert a UTC offset measured in minutes to one measured in a
    # fraction of a day.
    offset = Rational(utc_offset, 60 * 60 * 24)
    DateTime.new(year, month, day, hour, min, seconds, offset)
    end
end

require 'instagram'
require 'rubygems'

# unique class name: leave '< Slogger' but change InstagramLogger (e.g. LastFMLogger)
class InstagramLogger < Slogger

  def do_log
    if @config.key?(self.class.name)
      @instagram_config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !@instagram_config.key?('InstagramLogger_last_run') || @instagram_config['InstagramLogger_last_run'] == ""
        @log.warn("<Service> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      end
    else
      @log.warn("Instagram users have not been configured, please edit your slogger_config file.")
      return
    end

    if !@instagram_config.key?('access_token') || @instagram_config['access_token'] == ''
      @log.info("Instagram requires configuration, please run from the command line and follow the prompts")
      puts
      puts "------------- Instagram Configuration --------------"
      puts "\nSlogger will now open an authorization page in your default web browser. Copy the code you receive and return here.\n\n"
      puts "Press Enter to continue..."
      keypress = gets
      command = "/usr/bin/ruby lib/instagram_server.rb"
      output = `#{command}`
      puts "\n\n\n------------- Authentication Started -------------\n\n"
      print "Paste the code you received here: "
      output
      code = gets.strip
      @instagram_config['access_token'] = code
      log.info("Instagram successfully configured, run Slogger again to continue")
      return @instagram_config
    end

    @instagram_config['instagram_tags'] ||= '#social #instagram'
    tags = "\n\n#{@instagram_config['instagram_tags']}\n" unless @instagram_config['instagram_tags'] == ''

    today = @timespan

    Instagram.configure do |config|
      config.client_id = '3b878d6b67444f3c8bac914655bfe582'
      config.client_secret = '9cd3c532cd6a495890b2d2850647c8d1'
    end


    client = Instagram.client(:access_token => @instagram_config['access_token'])
    user = client.user
    instagram_media = client.user_recent_media
    begin
      instagram_media.each do |media|
        time_created = media['created_time'].to_i
        if !@instagram_config['backdate']
          break if Time.at(time_created) < today
        end
        image_url = media['images']['standard_resolution']['url']
        location_data = media['location'] unless media['location'] == nil
        likes_data = client.media_likes(media['id']) unless media['likes']['count'] == 0
        caption = media['caption']['text'] unless media['caption'] == nil
        
        comments = ""
        if media['comments']['count'] != 0
          comments += "### Comments\n\n"
          media['comments']['data'].each do |comment|
            comments += ">" + comment['text'] + " - " + comment['from']['full_name'] + "\n"
          end
        end
        
        like_names = likes_data.map{|n| n['full_name'] == "" ? n['username'] : n['full_name']} unless media['likes']['count'] == 0

        likes = ""
        if media['likes']['count'] != 0
          likes += "### #{media['likes']['count']} Likes\n\n"
          likes += like_names.join(", ")
        end

        # create an options array to pass to 'to_dayone'
        # all options have default fallbacks, so you only need to create the options you want to specify
        options = {}
        options['content'] = "## Instagram Photo\n\n#{caption}\n#{comments}\n#{likes}\n\n#{tags}"
        options['datestamp'] = Time.at(time_created).utc.iso8601
        options['starred'] = false
        options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

        if location_data
          options['location'] = true
          options['lat'] = location_data['latitude']
          options['long'] = location_data['longitude']
          options['place'] = location_data['name'] || false
        end


        # Create a journal entry
        # to_dayone accepts all of the above options as a hash
        # generates an entry base on the datestamp key or defaults to "now"
        sl = DayOne.new
        sl.to_dayone(options)
        sl.save_image(image_url, options['uuid'])
      end
    end
    @instagram_config['backdate'] = false
    return @instagram_config

  end
end

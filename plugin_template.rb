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
  'description' => ['Main description',
                    'additional notes. These will appear in the config file and should contain descriptions of configuration options',
                    'line 2, continue array as needed'],
  'service_username' => '', # update the name and make this a string or an array if you want to handle multiple accounts.
  'additional_config_option' => false
  'tags' => '@social @blogging' # A good idea to provide this with an appropriate default setting
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'ServiceLogger', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class ServiceLogger < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('service_username') || config['service_username'] == []
        @log.warn("<Service> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        username = config['service_username']
      end
    else
      @log.warn("<Service> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging <Service> posts for #{username}")

    additional_config_option = config['additional_config_option'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    today = @timespan

    # Perform necessary functions to retrieve posts

    # create an options array to pass to 'to_dayone'
    # all options have default fallbacks, so you only need to create the options you want to specify
    options = {}
    options['content'] = "## Post title\n\nContent#{tags}"
    options['datestamp'] = Time.now.utc.iso8601
    options['starred'] = true
    options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

    # Create a journal entry
    # to_dayone accepts all of the above options as a hash
    # generates an entry base on the datestamp key or defaults to "now"
    sl = DayOne.new
    sl.to_dayone(options)

    # To create an image entry, use `sl.to_dayone(options) if sl.save_image(imageurl,options['uuid'])`
    # save_image takes an image path and a uuid that must be identical the one passed to to_dayone
    # save_image returns false if there's an error

  end

  def helper_function(args)
    # add helper functions within the class to handle repetitive tasks
  end
end

=begin
Plugin: Rdio Logger
Description: Logs summary of activity on Rdio for the specified user
Author: [Julien Grimault](github.com/juliengrimault)
Configuration:
  rdio_username: juliengrimault
Notes:
  - multi-line notes with additional description and information (optional)
=end

config = {
  'description' => ['Logs summary of activity on Rdio for the specified user', 'rdio_username should be the Rdio username'],
  'rdio_username' => '',
  'tags' => '#social #music'
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'RdioLogger', 'config' => config })

require 'rdio'
class RdioLogger < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log

    unless is_logger_registered
      @log.warn("Rdio has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end

    unless is_logger_configured
      @log.warn("Rdio user has not been configured or an option is invalid, please edit your slogger_config file.")
      return
    end

    @log.info("Logging Rdio activity for #{username}")

    tags = logger_config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''



    
  
    if user['status'] != 'ok'
      @log.warn("")
    else
    end
    userKey = user['result']['key']
    activities = rdio.call('getActivityStream', { 'user' =>  userKey, 'scope' => 'user' })
    

    sl = DayOne.new
    sl.to_dayone({ 'content' => "## Post title\n\nContent#{tags}" }})

  end

  def is_logger_registered
    @config.key?(self.class.name)
  end

  def is_logger_configured
    config.key?('rdio_username') && config['rdio_username'] != []
  end

  def logger_config
    @config[self.class.name]
  end

  def try_get_user_key
    retries = 0
    success = false
    until success
      user_key = get_user_key
      if user_key
        success = true
      else
        break if $options[:max_retries] == retries
        retries += 1
        @log.error("Error getting user key for #{logger_config[rdio_username]}, retrying (#{retries}/#{$options[:max_retries]})")
        sleep 2
      end
    end
  end

  def get_user_key
    user = rdio.call('findUser', { 'vanityName' => logger_config['rdio_username'] })
    unless user['status'] == 'ok'
      return nil
    end
    user['result']['key']
  end

  def rdio
    @rdio ||= Rdio.new(['xxh3fr2p2s9xu9ps4b7gj888','ckwHAXrAkK'])
  end

end

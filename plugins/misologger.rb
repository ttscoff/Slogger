=begin
Plugin: Miso Logger
Description: Add the films and tv shows that you watch
Author: [Alejandro Martinez](http://alejandromp.com)
Configuration:
  miso_feed: "http://gomiso.com/feeds/user/ID/checkins.rss"
  pre_title: "Watched"
Notes:
  - multi-line notes with additional description and information (optional)
=end

config = { # description and a primary key (username, url, etc.) required
  'description' => ['MisoLogger downloads your feed from Miso and add the Films and TVShows that you watch to DayOne',
                    'The miso_feed parameter is like -> http://gomiso.com/feeds/user/ID/checkins.rss',
                    'You need the change the ID with your user id. You can find your user id going to http://gomiso.com/resources/widget and watching in the code snippet.'],
  'miso_feed' => "",
  'pre_title' => "Watched",
  'additional_config_option' => false,
  'tags' => '#social #entertainment' # A good idea to provide this with an appropriate default setting
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'MisoLogger', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class MisoLogger < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('miso_feed') || config['miso_feed'] == ''
        @log.warn("miso_feed has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        feed = config['miso_feed']
      end
    else
      @log.warn("MisoLogger has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging MisoLogger posts for #{feed}")

    additional_config_option = config['additional_config_option'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{tags}\n" unless @tags == ''
    today = @timespan

    # Perform necessary functions to retrieve posts

    ## Download Miso feed
    rss_content = ''
    begin
      url = URI.parse(feed)

      http = Net::HTTP.new url.host, url.port
      #http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      #http.use_ssl = true

      res = nil

      http.start do |agent|
        rss_content = agent.get(url.path).read_body
      end

    rescue Exception => e
      @log.error("ERROR fetching Miso feed" + e.to_s)
      # p e
    end
    @log.info(@timespan)
    
    watched = config['pre_title'] || ''

    ## Parse feed
    rss = RSS::Parser.parse(rss_content, false)
    rss.items.each { |item|
      break if Time.parse(item.pubDate.to_s) < @timespan

      @log.info("Adding " + item.title + " " + item.description)
    
      # create an options array to pass to 'to_dayone'
      # all options have default fallbacks, so you only need to create the options you want to specify
      options = {}
      options['content'] = "## " + watched + " " + item.title + "\n\n" + item.description + "#{tags}"
      options['datestamp'] = item.pubDate.to_s #Time.now.utc.iso8601
      #options['starred'] = true
      #options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip
  
      # Create a journal entry
      # to_dayone accepts all of the above options as a hash
      # generates an entry base on the datestamp key or defaults to "now"
      sl = DayOne.new
      sl.to_dayone(options)
    }

    # To create an image entry, use `sl.to_dayone(options) if sl.save_image(imageurl,options['uuid'])`
    # save_image takes an image path and a uuid that must be identical the one passed to to_dayone
    # save_image returns false if there's an error

  end

  def helper_function(args)
    # add helper functions within the class to handle repetitive tasks
  end
end

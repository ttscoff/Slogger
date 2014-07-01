=begin
Plugin: Miso Logger
Description: Add the films and tv shows that you watch
Author: [Alejandro Martinez](http://alejandromp.com)
Configuration:
  miso_feed: "http://gomiso.com/feeds/user/ID/checkins.rss"
  pre_title: "Watched"
Notes:
  - The miso_feed parameter is like -> http://gomiso.com/feeds/user/ID/checkins.rss
  - You need the change the ID with your user id. You can find your user id going to http://gomiso.com/resources/widget and watching in the code snippet.
=end

require 'nokogiri'

config = { # description and a primary key (username, url, etc.) required
  'description' => ['MisoLogger downloads your feed from Miso and add the Films and TVShows that you watch to DayOne',
                    'The miso_feed parameter is like -> http://gomiso.com/feeds/user/ID/checkins.rss',
                    'You need to change the ID with your user id. You can find your user id going to http://gomiso.com/resources/widget and watching in the code snippet.'],
  'miso_feed' => "",
  'pre_title' => "Watched",
  'save_images' => true,
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
        saveImages = config['save_images']
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
    end
    
    watched = config['pre_title'] || ''

    ## Parse feed
    rss = Nokogiri::XML(rss_content)
    content = ''
    image = ''
    date = Time.now.utc.iso8601
    rss.css('item').each { |item|
      break if Time.parse(item.at("pubDate").text) < @timespan
    
      title = item.at("title").text
      description = item.at("description").text
      date = item.at("pubDate").text
      image = item.at("miso|image_url").text
      
      content += "\n" + "## " + watched + " " + title + "\n" + description
    }

    if content != '' 
      # create an options array to pass to 'to_dayone'
      options = {}
      options['content'] = content + "\n" + "#{tags}"
      options['datestamp'] = Time.parse(date).utc.iso8601
      options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

      # Create a journal entry
      sl = DayOne.new
      if image == '' || !saveImages
        sl.to_dayone(options)
      else
        path = sl.save_image(image,options['uuid'])
        sl.store_single_photo(path,options) unless path == false
      end
    end
  end

  def helper_function(args)
    # add helper functions within the class to handle repetitive tasks
  end
end

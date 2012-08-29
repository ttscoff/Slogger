=begin
Plugin: GetGlue Logger
Description: Brief description (one line)
Author: [Dom Barnes](http://dombarnes.com)
Configuration:
  option_1_name: [ "example_value1" , "example_value2", ... ]
  option_2_name: example_value
Notes:
  - multi-line notes with additional description and information (optional)
=end

config = { # description and a primary key (username, url, etc.) required
  'description' => ['GetGlue logger grabs all your activity including checkins, likes and stickers',
                    'You will need the RSS feed of your Activity stream.'],
  'getglue_username' => 'getglue', # update the name and make this a string or an array if you want to handle multiple accounts.
  'getglue_feed' => "",
  'tags' => '@social @entertainment' # A good idea to provide this with an appropriate default setting
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'GetglueLogger', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class GetglueLogger < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('getglue_username') || config['getglue_username'] == []
        @log.warn("GetGlue has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        username = config['getglue_username']
      end
    else
      @log.warn("GetGlue has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging GetGlue posts for #{username}")
    @feed = config['getglue_feed']

    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    today = @timespan

    # Perform necessary functions to retrieve posts
    entrytext = ''
    rss_content = ''
    begin
      feed_url = URI.parse(@feed)
      feed_url.open do |f|
        rss_content = f.read
      end
    rescue Exception => e
      raise "ERROR fetching GetGlue feed"
      p e
    end
    content = ''
    rss = RSS::Parser.parse(rss_content, false)
    rss.items.each { |item|
      break if Time.parse(item.pubDate.to_s) < @timespan
      content += "* [#{item.pubDate.strftime('%H:%M %p')}](#{item.link}) - #{item.title}\n"
    }
    if content != ''
      entrytext = "## GetGlue Checkins for #{@timespan.strftime('%m-%d-%Y')}\n\n" + content + "\n#{@tags}"
    end

    # create an options array to pass to 'to_dayone'
    # all options have default fallbacks, so you only need to create the options you want to specify
    options = {}
    options['content'] = "## GetGlue Activity for #{@timespan.strftime('%m-%d-%Y')}\n\n#{content} #{tags}"
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
end
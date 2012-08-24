=begin
Plugin: FourSquare Logger
Description: Checks Foursquare feed once a day for that day's posts.
Author: [Jeff Mueller](https://github.com/jeffmueller)
Configuration:
  foursquare_feed: "https://feeds.foursquare.com/history/yourfoursquarehistory.rss"
  foursquare_tags: "@social @checkins"
Notes:
  Find your feed at <https://foursquare.com/feeds/> (in RSS option)
=end

default_config = {
    'feed' => "",
    'tags' => "@social @checkins"
}
$slog.register_plugin({ 'class' => 'FoursquareLogger', 'config' => default_config })

class FoursquareLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
    end
    if config['foursquare_feed'].nil? || config['foursquare_feed'] == ''
        @log.warn("FourSquare feed has not been configured or the feed is invalid, please edit your slogger_config file.")
        return
    end

    @log.info("Getting FourSquare checkins")
    if config['foursquare_feed'].nil? || config['foursquare_feed'] == ''
      @log.warn("FourSquare feed has not been configured or the feed is invalid, please edit your slogger_config file.")
      return
    end
    @feed = config['foursquare_feed']

    config['foursquare_tags'] ||= ''
    @tags = "\n\n#{config['foursquare_tags']}\n" unless config['foursquare_tags'] == ''
    @debug = config['debug'] || false

    entrytext = ''
    rss_content = ''
    begin
      feed_url = URI.parse(@feed)
      feed_url.open do |f|
        rss_content = f.read
      end
    rescue Exception => e
      raise "ERROR fetching Foursquare feed"
      p e
    end
    content = ''
    rss = RSS::Parser.parse(rss_content, false)
    rss.items.each { |item|
      break if Time.parse(item.pubDate.to_s) < @today
      content += "* [#{item.title}](#{item.link})\n"
    }
    if content != ''
      entrytext = "## Foursquare Checkins for #{@today.strftime('%m-%d-%Y')}\n\n" + content + "\n#{@tags}"
    end
    DayOne.new.to_dayone({'content' => entrytext}) unless entrytext == ''
  end
end

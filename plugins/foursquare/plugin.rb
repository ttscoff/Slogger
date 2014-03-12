=begin
Plugin: Foursquare Logger
Version: 1.0
Description: Checks Foursquare feed once a day for that day's posts.
Author: [Jeff Mueller](https://github.com/jeffmueller)
Configuration:
  foursquare_feed: "https://feeds.foursquare.com/history/yourfoursquarehistory.rss"
  foursquare_tags: "#social #checkins"
Notes:
  Find your feed at <https://foursquare.com/feeds/> (in RSS option)
=end

default_config = {
  'description' => [
  'foursquare_feed must refer to the address of your personal feed.','Your feed should be available at <https://foursquare.com/feeds/>'],
  'foursquare_feed' => "",
  'foursquare_tags' => "#social #checkins"
}
$slog.register_plugin({ 'class' => 'FoursquareLogger', 'config' => default_config })

class FoursquareLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('foursquare_feed') || config['foursquare_feed'] == ''
        @log.warn("Foursquare feed has not been configured, please edit your slogger_config file.")
        return
      else
        @feed = config['foursquare_feed']
      end
    else
      @log.warn("Foursquare feed has not been configured, please edit your slogger_config file.")
      return
    end

    @log.info("Getting Foursquare checkins")

    config['foursquare_tags'] ||= ''
    @tags = "\n\n(#{config['foursquare_tags']})\n" unless config['foursquare_tags'] == ''
    @debug = config['debug'] || false

    entrytext = ''
    rss_content = ''
    begin
      url = URI.parse(@feed)

      http = Net::HTTP.new url.host, url.port
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.use_ssl = true

      res = nil

      http.start do |agent|
        rss_content = agent.get(url.path).read_body
      end

    rescue Exception => e
      @log.error("ERROR fetching Foursquare feed")
      # p e
    end
    content = ''
    rss = RSS::Parser.parse(rss_content, false)
    rss.items.each { |item|
      break if Time.parse(item.pubDate.to_s) < @timespan
      content += "* [#{item.title}](#{item.link})\n"
    }
    if content != ''
      entrytext = "## Foursquare Checkins for #{@timespan.strftime(@date_format)}\n\n" + content + "\n#{@tags}"
    end
    DayOne.new.to_dayone({'content' => entrytext}) unless entrytext == ''
  end
end

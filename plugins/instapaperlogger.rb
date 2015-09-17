=begin
Plugin: Instapaper Logger
Version: 1.0.1
Description: Logs today's additions to Instapaper.
Notes:
  instapaper_feeds is an array of Instapaper RSS feeds
  - Find the RSS feed for any folder by inspecting the HTML source for a URL with type "application/rss+xml",
    and then prefix with 'https://www.instapaper.com/'
  - Seems to now need to use a secure connction to Instapaper
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  instapaper_feeds: [ 'https://www.instapaper.com/rss/106249/XXXXXXXXXXXXXX']
  instapaper_tags: "#social #reading"
=end
config = {
  'instapaper_description' => [
    'Logs today\'s posts to Instapaper.',
    'instapaper_feeds is an array of one or more RSS feeds',
    'Find the RSS feed for any folder at the bottom of a web interface page'],
  'instapaper_feeds' => [],
  'instapaper_include_content_preview' => true,
  'instapaper_tags' => '#social #reading'
}
$slog.register_plugin({ 'class' => 'InstapaperLogger', 'config' => config })

require 'rexml/document'

class InstapaperLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('instapaper_feeds') || config['instapaper_feeds'] == [] || config['instapaper_feeds'].empty?
        @log.warn("Instapaper feeds have not been configured, please edit your slogger_config file.")
        return
      end
    else
      @log.warn("Instapaper feeds have not been configured, please edit your slogger_config file.")
      return
    end

    sl = DayOne.new
    config['instapaper_tags'] ||= ''
    tags = "\n\n(#{config['instapaper_tags']})\n" unless config['instapaper_tags'] == ''
    today = @timespan.to_i

    @log.info("Getting Instapaper posts for #{config['instapaper_feeds'].length} accounts")
    output = ''

    config['instapaper_feeds'].each do |rss_feed|
      begin
        rss_content = ""
        open(rss_feed) do |f|
          rss_content = f.read
        end

        rss = RSS::Parser.parse(rss_content, false)
        feed_output = ''
        rss.items.each { |item|
          item_date = Time.parse(item.pubDate.to_s)
          if item_date > @timespan
            content = item.description.gsub(/\n/,"\n    ") unless item.description == ''
            feed_output += "* [#{item.title}](#{item.link})\n"
            feed_output += "\n     #{content}\n" if config['instapaper_include_content_preview'] == true
          else
            # The archive orders posts inconsistenly so older items can
            # show up before newer ones
            if rss.channel.title != "Instapaper: Archive"
              break
            end
          end
        }
        output += "#### #{rss.channel.title}\n\n" + feed_output + "\n" unless feed_output == ''
      rescue Exception => e
        raise "Error getting posts for #{rss_feed}"
        p e
        return ''
      end
    end
    unless output.strip == ''
      options = {}
      options['content'] = "## Instapaper reading\n\n#{output}#{tags}"
      sl.to_dayone(options)
    end
  end
end

=begin
Plugin: App.net Logger
Description: Logs today's posts to App.net.
Notes:
  appnet_feeds is an array of App.net RSS feeds
  - Feed is in the form https://alpha-api.app.net/feed/rss/users/@USERNAME/posts
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  appnet_feeds: [ 'https://alpha-api.app.net/feed/rss/users/@USERNAME/posts']
  appnet_tags: "@social @appnet"
Notes:

=end
config = {
  'appnet_description' => [
    'Logs posts for today from App.net',
    'appnet_feeds is an array of one or more App.net posts feeds'],
  'appnet_feeds' => [ ],
  'appnet_tags' => '@social @appnet',
  'appnet_save_hashtags' => false
}
$slog.register_plugin({ 'class' => 'AppNetLogger', 'config' => config })

require 'rexml/document'
require 'rss/dublincore'

class AppNetLogger < Slogger
  def do_log
    if config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('appnet_feeds') || config['appnet_feeds'] == [] || config['appnet_feeds'].empty?
        @log.warn("App.net feeds have not been configured, please edit your slogger_config file.")
        return
      end
    else
      @log.warn("App.net feeds have not been configured, please edit your slogger_config file.")
      return
    end

    sl = DayOne.new
    config['appnet_tags'] ||= ''
    tags = "\n\n#{config['appnet_tags']}\n" unless config['appnet_tags'] == ''
    today = @timespan.to_i

    @log.info("Getting App.net posts for #{config['appnet_feeds'].length} feeds")
    output = ''
    
    config['appnet_feeds'].each do |rss_feed|
      begin
        rss_content = ""
        open(rss_feed) do |f|
          rss_content = f.read
        end

        rss = RSS::Parser.parse(rss_content, true)
        feed_output = ''
        rss.items.each { |item|
          item_date = Time.parse(item.date.to_s)
          if item_date > @timespan
            content = ''
            feed_output += "* [#{item.pubDate.strftime('%I:%M %p')}](#{item.link}) #{item.title.gsub(/^\w+?: /,'').strip}#{content}"
          else
            break
          end
        }
        output += "#### [#{rss.channel.title}](#{rss.channel.link})\n\n" + feed_output + "\n" unless feed_output == ''
      rescue Exception => e
        puts "Error getting posts for #{rss_feed}"
        p e
        return ''
      end
    end
    unless output == ''
      options = {}
      options['content'] = "## App.net posts\n\n#{output}#{tags}"
      sl.to_dayone(options)
    end
  end
end

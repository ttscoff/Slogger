=begin
Plugin: Pinboard Logger
Version: 1.0
Description: Logs today's bookmarks from Pinboard.in.
Notes:
  pinboard_feeds is an array of Pinboard RSS feeds
  - There's an RSS button on every user/tag page on Pinboard, copy the link
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  pinboard_feeds: [ 'http://feeds.pinboard.in/rss/u:username/']
  pinboard_tags: "#social #bookmarks"
Notes:

=end
config = {
  'pinboard_description' => [
    'Logs bookmarks for today from Pinboard.in.',
    'pinboard_feeds is an array of one or more Pinboard RSS feeds'],
  'pinboard_feeds' => [],
  'pinboard_tags' => '#social #bookmarks',
  'pinboard_save_hashtags' => true
}
$slog.register_plugin({ 'class' => 'PinboardLogger', 'config' => config })

require 'rexml/document'
require 'rss/dublincore'

class PinboardLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('pinboard_feeds') || config['pinboard_feeds'] == [] || config['pinboard_feeds'].empty?
        @log.warn("Pinboard feeds have not been configured, please edit your slogger_config file.")
        return
      end
    else
      @log.warn("Pinboard feeds have not been configured, please edit your slogger_config file.")
      return
    end

    sl = DayOne.new
    config['pinboard_tags'] ||= ''
    tags = "\n\n#{config['pinboard_tags']}\n" unless config['pinboard_tags'] == ''
    today = @timespan.to_i

    @log.info("Getting Pinboard bookmarks for #{config['pinboard_feeds'].length} feeds")
    output = ''

    config['pinboard_feeds'].each do |rss_feed|
      begin
        rss_content = ""
        open(rss_feed) do |f|
          rss_content = f.read
        end

        rss = RSS::Parser.parse(rss_content, false)
        feed_output = ''
        rss.items.each { |item|
          item_date = Time.parse(item.date.to_s) + Time.now.gmt_offset
          if item_date > @timespan
            content = ''
            post_tags = ''
            content = "\n\n        " + item.description.gsub(/\n/,"\n        ").strip  unless item.description.nil?
            if config['pinboard_save_hashtags']
              post_tags = "\n    " + item.dc_subject.split(' ').map {|tag| "##{tag}"}.join(' ') + "\n" unless item.dc_subject.nil?
            end
            feed_output += "* [#{item.title.gsub(/\n/,' ').strip}](#{item.link})#{content}\n#{post_tags}"
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
      options['content'] = "## Pinboard bookmarks\n\n#{output}#{tags}"
      sl.to_dayone(options)
    end
  end
end

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
  pinboard_digest: true
Notes:

=end
config = {
    'pinboard_description' => [
        'Logs bookmarks for today from Pinboard.in.',
        'pinboard_feeds is an array of one or more Pinboard RSS feeds',
        'pinboard_digest true will group all new bookmarks into one post, false will split them into individual posts dated when the bookmark was created'],
    'pinboard_feeds' => [],
    'pinboard_tags' => '#social #bookmarks',
    'pinboard_save_hashtags' => true,
    'pinboard_digest' => true
}
$slog.register_plugin({'class' => 'PinboardLogger', 'config' => config})

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
          feed_output = '' unless config['pinboard_digest']
          item_date = Time.parse(item.date.to_s) + Time.now.gmt_offset
          if item_date > @timespan
            content = ''
            post_tags = ''
            if config['pinboard_digest']
              content = "\n\n        " + item.description.gsub(/\n/, "\n        ").strip unless item.description.nil?
            else
              content = "\n\n> " + item.description.gsub(/\n/, "\n> ").strip unless item.description.nil?
            end
            if config['pinboard_save_hashtags']
              post_tags = "\n" + item.dc_subject.split(' ').map { |tag| "##{tag}" }.join(' ') + "\n" unless item.dc_subject.nil?
            end
            feed_output += "#{config['pinboard_digest'] ? '* ' : ''}[#{item.title.gsub(/\n/, ' ').strip}](#{item.link})#{content}#{post_tags}"
          else
            break
          end
          output = feed_output unless config['pinboard_digest']
          unless output == '' || config['pinboard_digest']
            options = {}
            options['datestamp'] = Time.parse(item.date.to_s).utc.iso8601
            options['content'] = "## New Pinboard bookmark\n#{output}#{tags}"
            sl.to_dayone(options)
          end
        }
        output += "#### [#{rss.channel.title}](#{rss.channel.link})\n\n" + feed_output + "\n" unless feed_output == ''
      rescue Exception => e
        puts "Error getting posts for #{rss_feed}"
        p e
        return ''
      end
    end
    unless output == '' || !config['pinboard_digest']
      options = {}
      options['content'] = "## Pinboard bookmarks\n\n#{output}#{tags}"
      sl.to_dayone(options)
    end
  end
end

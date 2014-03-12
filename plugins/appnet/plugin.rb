=begin
Plugin: App.net Logger
Version: 1.1
Description: Logs today's posts to App.net.
Notes:
  appnet_usernames is an array of App.net user names
Author: [Alan Schussman](http://schussman.com)
Configuration:
  appnet_usernames: [ ]
  appnet_tags: "#social #appnet"
  appnet_save_replies: false
  appnet_digest: true
Notes:

=end
config = {
  'appnet_description' => [
    'Logs posts for today from App.net',
    'appnet_usernames is an array of App.net user names'],
  'appnet_usernames' => [ ],
  'appnet_tags' => '#social #appnet',
  'appnet_save_replies' => false,
  'appnet_digest' => true
}
$slog.register_plugin({ 'class' => 'AppNetLogger', 'config' => config })

require 'rexml/document'
require 'rss/dublincore'

class AppNetLogger < Slogger
  def linkify(input)
    input.gsub(/@(\S+)/,"[\\0](https://alpha.app.net/\\1)").gsub(/(http|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:\/~\+#]*[\w\-\@^=%&amp;\/~\+#])?/,"<\\0>")
  end

  def do_log
    if config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('appnet_usernames') || config['appnet_usernames'] == [] || config['appnet_usernames'].empty?
        @log.warn("App.net user names have not been configured, please edit your slogger_config file.")
        return
      end
    else
      @log.warn("App.net user names have not been configured, please edit your slogger_config file.")
      return
    end

    sl = DayOne.new
    config['appnet_tags'] ||= ''
    tags = "\n\n(#{config['appnet_tags']})\n" unless config['appnet_tags'] == ''
    today = @timespan.to_i

    @log.info("Getting App.net posts for #{config['appnet_usernames'].length} feeds")
    if config['save_appnet_replies']
      @log.info("replies: true")
    end
    output = ''

    config['appnet_usernames'].each do |user|
      begin
        rss_feed = "https://alpha-api.app.net/feed/rss/users/@"+ user + "/posts"

        url = URI.parse rss_feed

        http = Net::HTTP.new url.host, url.port
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.use_ssl = true

        rss_content = nil

        http.start do |agent|
          rss_content = agent.get(url.path).read_body
        end

        rss = RSS::Parser.parse(rss_content, true)
        feed_output = ''
        rss.items.each { |item|
          item_date = Time.parse(item.date.to_s) + Time.now.gmt_offset
          if item_date > @timespan
            content = ''
            item.title = item.title.gsub(/^@#{user}: /,'').strip   # remove user's own name from front of post
            item.title = item.title.gsub(/\n/,"\n    ") if config['appnet_digest']           # fix for multi-line posts displayed in markdown
            if item.title =~ /^@/
              if config['appnet_save_replies']
                if config['appnet_digest']
                  feed_output += "* [#{item_date.strftime(@time_format)}](#{item.link}) #{linkify(item.title)}#{content}\n"
                else
                  feed_output = "#{linkify(item.title)}\n"
                end
              end
            else
              if config['appnet_digest']
                feed_output += "* [#{item_date.strftime(@time_format)}](#{item.link}) #{linkify(item.title)}#{content}\n"
              else
                feed_output = "#{linkify(item.title)}\n"
              end
            end
            unless config['appnet_digest']
              output = feed_output
              unless output == ''
                options = {}
                options['datestamp'] = Time.parse(item.date.to_s).utc.iso8601
                options['content'] = "## App.net [post](#{item.link}) by [@#{user}](#{rss.channel.link})\n#{output}#{tags}"
                sl.to_dayone(options)
              end
            end
          else
            break
          end
        }
        if config['appnet_digest']
          output += "#### [#{rss.channel.title}](#{rss.channel.link})\n\n" + feed_output + "\n" unless feed_output == ''
        end
      rescue Exception => e
        puts "Error getting posts for #{rss_feed}"
        p e
        return ''
      end
    end
    unless output == '' || !config['appnet_digest']
      options = {}
      options['content'] = "## App.net posts\n\n#{output}#{tags}"
      sl.to_dayone(options)
    end
  end
end

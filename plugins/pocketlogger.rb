=begin
Plugin: Pocket Logger
Version: 2.0
Description: Logs today's additions to Pocket.
Notes:
  pocket_username is a string with your Pocket username
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  pocket_username: 'your_username'
  pocket_passwd: "your_password" // if RSS Feed password protection is on
  pocket_tags: "#social #reading"
Notes:

=end
config = {
  'pocket_description' => [
    'Logs today\'s posts to Pocket.',
    'pocket_username is a string with your Pocket username',
    'pocket_passwd is a string with your Pocket password'],
  'pocket_username' => '',
  'pocket_passwd' => '',
  'pocket_tags' => '#social #reading'
}
$slog.register_plugin({ 'class' => 'PocketLogger', 'config' => config })

require 'rexml/document'

class PocketLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('pocket_username') || config['pocket_username'].nil?
        @log.warn("Pocket username has not been configured, please edit your slogger_config file.")
        return
      end
    else
      @log.warn("Pocket has not been configured, please edit your slogger_config file.")
      return
    end

    sl = DayOne.new
    config['pocket_tags'] ||= ''
    username = config['pocket_username']
    password = config['pocket_passwd']
    tags = "\n\n(#{config['pocket_tags']})\n" unless config['pocket_tags'] == ''
    today = @timespan

    @log.info("Getting Pocket posts for #{username}")
    output = ''

    ["read","unread"].each {|kind|
      rss_feed = "https://getpocket.com/users/#{username.strip}/feed/#{kind}"
      title = case kind
      when "read" then "### Items read today:"
      when "unread" then "### Items saved today:"
      end

      begin
        rss_content = ""
        open(rss_feed, http_basic_authentication: [username, password]) do |f|
          rss_content = f.read
        end
        tempoutput = ""
        rss = RSS::Parser.parse(rss_content, false)

        rss.items.each { |item|
          item_date = Time.parse(item.pubDate.to_s)
          if item_date > @timespan
            tempoutput += "* [#{item.title}](#{item.link})\n"
          else
            break
          end
        }
        output += "#{title}\n\n#{tempoutput}\n\n" unless tempoutput == ""

      rescue Exception => e
        puts "Error getting posts for #{username}"
        p e
        return ''
      end
    }
    unless output == ''
      options = {}
      options['content'] = "## Pocket reading\n\n#{output}#{tags}"
      sl.to_dayone(options)
    end
  end
end

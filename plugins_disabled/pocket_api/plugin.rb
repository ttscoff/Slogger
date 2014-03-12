=begin
Plugin: Pocket Logger
Description: Logs today's additions to Pocket.
Notes:
  pocket_username is a string with your Pocket username
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  pocket_username: "your_username"
  pocket_passwd: "your_password"
  pocket_tags: "#social #reading"
  posts_to_get: "read" or "unread" or leave blank for all
Notes:

=end
config = {
  'pocket_description' => [
    'Logs today\'s posts to Pocket.',
    'pocket_username is a string with your Pocket username',
    'pocket_passwd is a string with your Pocket password',
    'pocket_tags are the tags you want assigned to each dayone entry',
    'posts_to_get allows you to choose read, unread or all items'],
  'pocket_username' => '',
  'pocket_passwd' => '',
  'pocket_tags' => '#social #reading',
  'posts_to_get' => ''
}
$slog.register_plugin({ 'class' => 'PocketLogger', 'config' => config })

require 'rexml/document'
require 'oauth'
#require 'ruby-debug'

class PocketLogger < Slogger
    #Debugger.start
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('pocket_username') || config['pocket_username'].nil? || !config.key?('pocket_passwd') || config['pocket_passwd'].nil?
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
    passwd= config['pocket_passwd']
    posts_to_get=config['posts_to_get']
    tags = "\n\n#{config['pocket_tags']}\n" unless config['pocket_tags'] == ''
    today = @timespan
    yest=(Time.now-86400).to_i
    pkey="29ed8r79To6fuG8e9bA480GD77g5P586"
    @log.info("Getting Pocket #{posts_to_get} posts for #{username}")
    output = ''
    burl="https://readitlaterlist.com/v2/get?username=#{username}&password=#{passwd}&state=#{posts_to_get}&since=#{yest}&apikey=#{pkey}"
    curl=URI.parse(burl)

    begin
        res=Net::HTTP.start(curl.host) { |http| http.get("#{curl.path}?#{curl.query}") }
        entries=JSON.parse(res.body)
        entries["list"].each do | k, v|
            output+="#{v["title"]} // #{v["url"]} \n\n "
        end
    rescue Exception => e
      puts "Error getting #{posts_to_get} posts for #{username}".gsub!("  "," ")
      p e
      return ''
    end
    unless output == ''
      options = {}
      options['content'] = "Pocket reading\n\n#{output}#{tags}"
      sl.to_dayone(options)
    end
  end
end

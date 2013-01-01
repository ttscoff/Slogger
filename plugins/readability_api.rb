=begin
Plugin: Readability Logger
Description: Logs today's additions to Readability.
Author: [Joseph Scavone](http://scav1.com)
Notes:
  read_username is a string with your Readability username
  read_passwd is a string with your Readability password
  read_key is a string with your Readability API key
  read_secret is a string with your Readability API secret
Configuration:
  read_username: "your_username"
  read_passwd: "your_password"
  read_key: "your_key"
  read_secret: "your_secret"
  read_tags: "#social #reading"
  favorites_only: true|false
Notes:

=end
config = {
  'read_description' => [
    'Logs today\'s posts to Readability.',
    'read_username is a string with your Readability username',
    'read_passwd is a string with your Readability password',
    'read_key is a string with your Readability API key',
    'read_secret is a string with your Readability API secret',
    'favorites_only is a boolean to only return favorites'],
  'read_username' => nil,
  'read_passwd' => nil,
  'read_key' => nil,
  'read_secret' => nil,
  'read_tags' => '#social #reading',
  'favorites_only' => false
}
$slog.register_plugin({ 'class' => 'ReadabilityLogger', 'config' => config })

require 'rubygems'
require 'oauth'

class ReadabilityLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('read_username') || config['read_username'].nil? || !config.key?('read_passwd') || config['read_passwd'].nil?
        @log.warn("Readability username has not been configured, please edit your slogger_config file.")
        return
      end
      if !config.key?('read_key') || config['read_key'].nil? || !config.key?('read_secret') || config['read_secret'].nil?
        @log.warn("Readability API has not been configured, please edit your slogger_config file.")
        return
      end
    else
      @log.warn("Readability has not been configured, please edit your slogger_config file.")
      return
    end

    sl = DayOne.new
    config['read_tags'] ||= ''
    username = config['read_username']
    passwd = config['read_passwd']
    consumer_key = config['read_key']
    consumer_secret = config['read_secret']
    favorites_only=config['favorites_only'] ? 1 : 0
    tags = "\n\n#{config['read_tags']}\n" unless config['read_tags'] == ''
    yest = @timespan.strftime("%Y-%m-%d")
    @log.info("Getting Readability posts for #{username}")
    output = ''
  
    begin
      consumer = OAuth::Consumer.new(consumer_key, consumer_secret, 
        :site               => "https://www.readability.com",
        :access_token_path  => '/api/rest/v1/oauth/access_token/')
      access_token =  consumer.get_access_token(nil, {}, {
        'x_auth_mode' => 'client_auth', 
        'x_auth_username' => username, 
        'x_auth_password' => passwd})
    rescue OAuth::Unauthorized => e
      @log.error("Error with Readability API key/secret: #{e}")
    end

    unless access_token == nil
      begin
        burl = "/api/rest/v1/bookmarks/?archive=0&added_since=#{yest}&favorite=#{favorites_only}"
        res = access_token.get(burl)
        entries=JSON.parse(res.body)
        entries["bookmarks"].each do |item|
          output+="[#{item["article"]["title"]}](https://www.readability.com/articles/#{item["article"]["id"]})\n>#{item["article"]["excerpt"]}\n\n"
        end
      rescue Exception => e
        @log.error("Error getting reading list for #{username}: #{e}")
        return ''
      end
      unless output == ''
        options = {}
        options['content'] = "Readability reading\n\n#{output}#{tags}"
        sl.to_dayone(options)
      end
    end
  end
end
=begin
Plugin: Twitter Logger
Version: 3.0
Description: Logs updates and favorites for specified Twitter users
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  twitter_users: [ "handle1" , "handle2", ... ]
  save_images: true
  droplr_domain: d.pr
  twitter_tags: "#social #blogging"
Notes:

=end
config = {
  'description' => [
    'Logs updates and favorites for specified Twitter users',
    'twitter_users should be an array of Twitter usernames, e.g. [ ttscoff, markedapp ]',
    'save_images (true/false) determines whether TwitterLogger will look for image urls and include them in the entry',
    'save_favorites (true/false) determines whether TwitterLogger will look for the favorites of the given usernames and include them in the entry',
    'save_images_from_favorites (true/false) determines whether TwitterLogger will download images for the favorites of the given usernames and include them in the entry',
    'save_retweets (true/false) determines whether TwitterLogger will include retweets in the posts for the day',
    'droplr_domain: if you have a custom droplr domain, enter it here, otherwise leave it as d.pr ',
    'oauth_token and oauth_secret should be left blank and will be filled in by the plugin'],
  'twitter_users' => [],
  'save_favorites' => true,
  'save_images' => true,
  'save_images_from_favorites' => true,
  'droplr_domain' => 'd.pr',
  'twitter_tags' => '#social #twitter',
  'oauth_token' => '',
  'oauth_token_secret' => '',
  'exclude_replies' => true
}
$slog.register_plugin({ 'class' => 'TwitterLogger', 'config' => config })

require 'twitter'
require 'twitter_oauth'

class TwitterLogger < Slogger

  def get_body(target, depth = 0)

    final_url = RedirectFollower.new(target).resolve
    url = URI.parse(final_url.url)

    host, port = url.host, url.port if url.host && url.port
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(host, port) {|http| http.request(req) }

    return res.body
  end

  def download_images(images)

    @twitter_config['twitter_tags'] ||= ''
    tags = "\n\n#{@twitter_config['twitter_tags']}\n" unless @twitter_config['twitter_tags'] == ''

    images.each do |image|
      next if image['content'].nil? || image['url'].nil?
      options = {}
      options['content'] = "#{image['content']}#{tags}"
      options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip
      sl = DayOne.new
      path = sl.save_image(image['url'],options['uuid'])
      sl.store_single_photo(path,options) unless path == false
    end

    return true
  end

  def get_tweets(user,type='timeline')
    @log.info("Getting Twitter #{type} for #{user}")

    Twitter.configure do |auth_config|
      auth_config.consumer_key = "53aMoQiFaQfoUtxyJIkGdw"
      auth_config.consumer_secret = "Twnh3SnDdtQZkJwJ3p8Tu5rPbL5Gt1I0dEMBBtQ6w"
      auth_config.oauth_token = @twitter_config["oauth_token"]
      auth_config.oauth_token_secret = @twitter_config["oauth_token_secret"]
    end

    case type

      when 'favorites'
        params = { "count" => 250, "screen_name" => user, "include_entities" => true }
        tweet_obj = Twitter.favorites(params)

      when 'timeline'
        params = { "count" => 250, "screen_name" => user, "include_entities" => true, "exclude_replies" => @twitter_config['exclude_replies'], "include_rts" => @twitter_config['save_retweets']}
        tweet_obj = Twitter.user_timeline(params)

    end

    images = []
    tweets = []
    begin
      tweet_obj.each { |tweet|
        today = @timespan
        tweet_date = tweet.created_at
        break if tweet_date < today
        tweet_text = tweet.text.gsub(/\n/,"\n\t")
        if type == 'favorites'
          # TODO: Prepend favorite's username/link
          screen_name = tweet.user.status.user.screen_name
          tweet_text = "[#{screen_name}](http://twitter.com/#{screen_name}): #{tweet_text}"
        end

        tweet_id = tweet.id
        unless tweet.urls.empty?
          tweet.urls.each { |url|
            tweet_text.gsub!(/#{url.url}/,"[#{url.display_url}](#{url.expanded_url})")
          }
        end
        begin
          if @twitter_config['save_images']
            tweet_images = []
            unless tweet.media.empty?
              tweet.media.each { |img|
                tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => img.media_url }
              }
            end

              # new logic for the picture links and added yfrog (nr)
            tweet_text.scan(/\((http:\/\/twitpic.com\/\w+?)\)/).each do |picurl|
              aurl=URI.parse(picurl[0])
              burl="http://twitpic.com/show/large#{aurl.path}"
              curl = RedirectFollower.new(burl).resolve
              final_url=curl.url
              tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => final_url } unless final_url.nil?
              #tweet_images=[tweet_text,tweet_date.utc.iso8601,final_url] unless final_url.nil?
            end
            tweet_text.scan(/\((http:\/\/campl.us\/\w+?)\)/).each do |picurl|
              aurl=URI.parse(picurl[0])
              burl="http://campl.us/#{aurl.path}:800px"
              curl = RedirectFollower.new(burl).resolve
              final_url=curl.url
              tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => final_url } unless final_url.nil?
            end
            # Drop.lr downloads temporarily broken
            # tweet_text.scan(/\((http:\/\/#{@twitter_config['droplr_domain']}\/\w+?)\)/).each do |picurl|
            #   # final_url = self.get_body(picurl[0]).match(/"(https:\/\/s3.amazonaws.com\/files.droplr.com\/.+?)"/)
            #   tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => picurl[0]+"+" } # unless final_url.nil?
            # end

            tweet_text.scan(/\((http:\/\/instagr\.am\/\w\/.+?\/)\)/).each do |picurl|
              final_url=self.get_body(picurl[0]).match(/http:\/\/distilleryimage.*?\.com\/[a-z0-9_]+\.jpg/)
              tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => final_url[0] } unless final_url.nil?
            end
            tweet_text.scan(/http:\/\/[\w\.]*yfrog\.com\/[\w]+/).each do |picurl|
              aurl=URI.parse(picurl)
              burl="http://yfrog.com#{aurl.path}:medium"
              curl = RedirectFollower.new(burl).resolve
              final_url=curl.url
              tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => final_url } unless final_url.nil?
            end
          end
        rescue Exception => e
          @log.warn("Failure gathering image urls")
          p e
        end

        if tweet_images.empty? or !@twitter_config["save_images_from_#{type}"]
          tweets.push("* [[#{tweet_date.strftime(@time_format)}](https://twitter.com/#{user}/status/#{tweet_id})] #{tweet_text}")
        else
          images.concat(tweet_images)
        end
      }
      if @twitter_config['save_images'] && images != []
        begin
          self.download_images(images)
        rescue Exception => e
          @log.warn("Failure downloading images: #{e}")
          # p e
        end
      end
      return tweets.reverse.join("\n")
    rescue Exception => e
      @log.warn("Error getting #{type} for #{user}")
      p e
      return false
    end

  end

  def do_log
    if @config.key?(self.class.name)
        @twitter_config = @config[self.class.name]
        if !@twitter_config.key?('twitter_users') || @twitter_config['twitter_users'] == []
          @log.warn("Twitter users have not been configured, please edit your slogger_config file.")
          return
        end
    else
      @log.warn("Twitter users have not been configured, please edit your slogger_config file.")
      return
    end

    if @twitter_config['oauth_token'] == '' || @twitter_config['oauth_token_secret'] == ''
      client = TwitterOAuth::Client.new(
          :consumer_key => "53aMoQiFaQfoUtxyJIkGdw",
          :consumer_secret => "Twnh3SnDdtQZkJwJ3p8Tu5rPbL5Gt1I0dEMBBtQ6w"
      )

      request_token = client.authentication_request_token(
        :oauth_callback => 'oob'
      )
      @log.info("Twitter requires configuration, please run from the command line and follow the prompts")
      puts
      puts "------------- Twitter Configuration --------------"
      puts "Slogger will now open an authorization page in your default web browser. Copy the code you receive and return here."
      print "Press Enter to continue..."
      gets
      %x{open "#{request_token.authorize_url}"}
      print "Paste the code you received here: "
      code = gets.strip

      access_token = client.authorize(
        request_token.token,
        request_token.secret,
        :oauth_verifier => code
      )
      if client.authorized?
        @twitter_config['oauth_token'] = access_token.params["oauth_token"]
        @twitter_config['oauth_token_secret'] = access_token.params["oauth_token_secret"]
        puts
        log.info("Twitter successfully configured, run Slogger again to continue")
        return @twitter_config
      end
    end
    @twitter_config['save_images'] ||= true
    @twitter_config['droplr_domain'] ||= 'd.pr'

    sl = DayOne.new
    @twitter_config['twitter_tags'] ||= '#social #twitter'
    tags = "\n\n#{@twitter_config['twitter_tags']}\n" unless @twitter_config['twitter_tags'] == ''

    @twitter_config['twitter_users'].each do |user|

      tweets = try { self.get_tweets(user, 'timeline') }

      if @twitter_config['save_favorites']
        favs = try { self.get_tweets(user, 'favorites')}
      else
        favs = ''
      end

      unless tweets == ''
        tweets = "## Tweets\n\n### Posts by @#{user} on #{Time.now.strftime(@date_format)}\n\n#{tweets}#{tags}"
        sl.to_dayone({'content' => tweets})
      end
      unless favs == ''
        favs = "## Favorite Tweets\n\n### Favorites from @#{user} for #{Time.now.strftime(@date_format)}\n\n#{favs}#{tags}"
        sl.to_dayone({'content' => favs})
      end
    end

    return @twitter_config
  end

  def try(&action)
    retries = 0
    success = false
    until success || $options[:max_retries] == retries
      result = yield
      if result
        success = true
      else
        retries += 1
        @log.error("Error performing action, retrying (#{retries}/#{$options[:max_retries]})")
        sleep 2
      end
    end
    result
  end

end

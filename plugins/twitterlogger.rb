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
    'digest_timeline: if true will create a single entry for all tweets',
    'oauth_token and oauth_secret should be left blank and will be filled in by the plugin'],
  'twitter_users' => [],
  'save_favorites' => true,
  'save_images' => true,
  'save_images_from_favorites' => true,
  'droplr_domain' => 'd.pr',
  'twitter_tags' => '#social #twitter',
  'oauth_token' => '',
  'oauth_token_secret' => '',
  'exclude_replies' => true,
  'save_retweets' => false,
  #'digest_favorites' => true, # Not implemented yet
  'digest_timeline' => true
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

  def single_entry(tweet)

    @twitter_config['twitter_tags'] ||= ''
    
    options = {}
    options['content'] = "#{tweet[:text]}\n\n-- [@#{tweet[:screen_name]}](https://twitter.com/#{tweet[:screen_name]}/status/#{tweet[:id]})\n\n(#{@twitter_config['twitter_tags']})\n"
    tweet_time = Time.parse(tweet[:date].to_s)
    options['datestamp'] = tweet_time.utc.iso8601

    sl = DayOne.new
    
    if tweet[:images].empty?
      sl.to_dayone(options)
    else
      tweet[:images].each do |imageurl|
        options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip
        path = sl.save_image(imageurl,options['uuid'])
        sl.store_single_photo(path,options) unless path == false
      end
    end

    return true
  end

  def get_tweets(user,type='timeline')
    @log.info("Getting Twitter #{type} for #{user}")

    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = "53aMoQiFaQfoUtxyJIkGdw"
      config.consumer_secret     = "Twnh3SnDdtQZkJwJ3p8Tu5rPbL5Gt1I0dEMBBtQ6w"
      config.access_token        = @twitter_config["oauth_token"]
      config.access_token_secret = @twitter_config["oauth_token_secret"]
    end

    case type

      when 'favorites'
        params = { :count => 250, :screen_name => user, :include_entities => true }
        tweet_obj = client.favorites(params)

      when 'timeline'
        params = { :count => 250, :screen_name => user, :include_entities => true, :exclude_replies => @twitter_config['exclude_replies'], :include_rts => @twitter_config['save_retweets']}
        tweet_obj = client.user_timeline(params)

    end

    images = []
    tweets = []
    begin
      tweet_obj.each { |tweet|
        today = @timespan
        tweet_date = tweet.created_at
        break if tweet_date < today
        tweet_text = tweet.text.gsub(/\n/,"\n\t")
        screen_name = user

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
                tweet_images.push(img.media_url.to_s)
              }
            end

              # new logic for the picture links and added yfrog (nr)
            tweet_text.scan(/\((http:\/\/twitpic.com\/\w+?)\)/).each do |picurl|
              aurl=URI.parse(picurl[0])
              burl="http://twitpic.com/show/large#{aurl.path}"
              curl = RedirectFollower.new(burl).resolve
              final_url=curl.url
              tweet_images.push(final_url) unless final_url.nil?
              #tweet_images=[tweet_text,tweet_date.utc.iso8601,final_url] unless final_url.nil?
            end
            tweet_text.scan(/\((http:\/\/campl.us\/\w+?)\)/).each do |picurl|
              aurl=URI.parse(picurl[0])
              burl="http://campl.us/#{aurl.path}:800px"
              curl = RedirectFollower.new(burl).resolve
              final_url=curl.url
              tweet_images.push(final_url) unless final_url.nil?
            end
            # Drop.lr downloads temporarily broken
            tweet_text.scan(/\((http:\/\/#{@twitter_config['droplr_domain']}\/\w+?)\)/).each do |picurl|
              # final_url = self.get_body(picurl[0]).match(/"(https:\/\/s3.*?\.amazonaws\.com\/droplr\.storage\/.+?)"/)
              # tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => picurl[0]+"+" } # unless final_url.nil?
              aurl = URI.parse(picurl[0]+"+")
              curl = RedirectFollower.new(aurl).resolve
              tweet_images.push(curl) unless curl.nil?
            end

            tweet_text.scan(/\((http:\/\/instagr\.am\/\w\/.+?\/)\)/).each do |picurl|
              final_url=self.get_body(picurl[0]).match(/http:\/\/distilleryimage.*?\.com\/[a-z0-9_]+\.jpg/)
              tweet_images.push(final_url[0]) unless final_url.nil?
            end
            tweet_text.scan(/http:\/\/[\w\.]*yfrog\.com\/[\w]+/).each do |picurl|
              aurl=URI.parse(picurl)
              burl="http://yfrog.com#{aurl.path}:medium"
              curl = RedirectFollower.new(burl).resolve
              final_url=curl.url
              tweet_images.push(final_url) unless final_url.nil?
            end
          end
        rescue Exception => e
          @log.warn("Failure gathering image urls")
          p e
        end

        if tweet_id
          tweets.push({:text => tweet_text, :date => tweet_date, :screen_name => screen_name, :images => tweet_images, :id => tweet_id})
        end
      }
      return tweets
    rescue Exception => e
      @log.warn("Error getting #{type} for #{user}")
      p e
      return []
    end

  end

  def split_days(tweets)
    # tweets.push({:text => tweet_text, :date => tweet_date, :screen_name => screen_name, :images => tweet_images, :id => tweet_id})
    dated_tweets = {}
    tweets.each {|tweet|
      date = tweet[:date].strftime('%Y-%m-%d')
      dated_tweets[date] = [] unless dated_tweets[date]
      dated_tweets[date].push(tweet)
    }
    dated_tweets
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
      puts "#{request_token.authorize_url}"
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

    defined?(@twitter_config['save_images']).nil? and @twitter_config['save_images'] = true
    defined?(@twitter_config['digest_timeline']).nil? and @twitter_config['digest_timeline'] = true
    @twitter_config['droplr_domain'] ||= 'd.pr'

    sl = DayOne.new
    @twitter_config['twitter_tags'] ||= ''
    tags = "\n\n(#{@twitter_config['twitter_tags']})\n" unless @twitter_config['twitter_tags'] == ''

    @twitter_config['twitter_users'].each do |user|

      tweets = try { self.get_tweets(user, 'timeline') }

      if @twitter_config['save_favorites']
        favs = try { self.get_tweets(user, 'favorites')}
      else
        favs = []
      end

      unless tweets.empty?
        
        if @twitter_config['digest_timeline']
          dated_tweets = split_days(tweets)
          dated_tweets.each {|k,v|
            content = "## Tweets\n\n### Posts by @#{user} on #{Time.parse(k).strftime(@date_format)}\n\n"
            content << digest_entry(v, tags)
            sl.to_dayone({'content' => content, 'datestamp' => Time.parse(k).utc.iso8601})
            if @twitter_config['save_images']
              v.select {|t| !t[:images].empty? }.each {|t| self.single_entry(t) }
            end
          }

        else
          tweets.each do |t|
            self.single_entry(t)
          end
        end

      end
      unless favs.empty?
        dated_tweets = split_days(favs)
        dated_tweets.each {|k,v|
          content = "## Favorite Tweets\n\n### Favorites from @#{user} on #{Time.parse(k).strftime(@date_format)}\n\n"
          content << digest_entry(v, tags)
          sl.to_dayone({'content' => content, 'datestamp' => Time.parse(k).utc.iso8601})
          if @twitter_config['save_images_from_favorites']
            v.select {|t| !t[:images].empty? }.each {|t| self.single_entry(t) }
          end
        }
      end
    end

    return @twitter_config
  end

  def digest_entry(tweets, tags)
    tweets.reverse.map do |t|
      "* [[#{t[:date].strftime(@time_format)}](https://twitter.com/#{t[:screen_name]}/status/#{t[:id]})] #{t[:text]}\n"
    end.join("\n") << "\n#{tags}"
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

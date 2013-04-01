=begin
Plugin: Twitter Logger
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
    'save_retweets (true/false) determines whether TwitterLogger will look for the retweets of the given usernames and include them in the entry',
    'save_images_from_retweets (true/false) determines whether TwitterLogger will download images for the retweets of the given usernames and include them in the entry',
    'droplr_domain: if you have a custom droplr domain, enter it here, otherwise leave it as d.pr '],
  'twitter_users' => [],
  'save_favorites' => true,
  'save_images' => true,
  'save_images_from_favorites' => true,
  'save_retweets' => true,
  'save_images_from_retweets' => true,
  'droplr_domain' => 'd.pr',
  'twitter_tags' => '#social #twitter'
}
$slog.register_plugin({ 'class' => 'TwitterLogger', 'config' => config })

require 'rexml/document'

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
    case type
      when 'favorites'
        url = URI.parse("http://api.twitter.com/1/favorites.xml?count=200&screen_name=#{user}&include_entities=true&count=200")

      when 'timeline'
        url = URI.parse("http://api.twitter.com/1/statuses/user_timeline.xml?screen_name=#{user}&count=200&exclude_replies=true&include_entities=true")

      when 'retweets'
        url = URI.parse("http://api.twitter.com/1/statuses/retweeted_by_user.xml?screen_name=#{user}&count=200&include_entities=true")

    end

    tweets = []
    images = []
    begin
      begin
        res = Net::HTTP.get_response(url).body
      rescue Exception => e
        @log.warn("Failure getting response from Twitter")
        # p e
        return false
      end
      REXML::Document.new(res).elements.each("statuses/status") { |tweet|
        today = @timespan
        tweet_date = Time.parse(tweet.elements['created_at'].text)
        break if tweet_date < today
        tweet_text = tweet.elements['text'].text.gsub(/\n/,"\n\t")
        if type == 'favorites'
          # TODO: Prepend favorite's username/link
          screen_name = tweet.elements['user/screen_name'].text
          tweet_text = "[#{screen_name}](http://twitter.com/#{screen_name}): #{tweet_text}"
        end
        tweet_id = tweet.elements['id'].text
        unless tweet.elements['entities/urls'].nil? || tweet.elements['entities/urls'].length == 0
          tweet.elements.each("entities/urls/url") { |url|
            tweet_text.gsub!(/#{url.elements['url'].text}/,"[#{url.elements['display_url'].text}](#{url.elements['expanded_url'].text})")
          }
        end
        begin
          if @twitter_config['save_images']
            tweet_images = []
            unless tweet.elements['entities/media'].nil? || tweet.elements['entities/media'].length == 0
              tweet.elements.each("entities/media/creative") { |img|
                tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => img.elements['media_url'].text }
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
      # p e
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

    @twitter_config['save_images'] ||= true
    @twitter_config['droplr_domain'] ||= 'd.pr'

    sl = DayOne.new
    @twitter_config['twitter_tags'] ||= ''
    tags = "\n\n#{@twitter_config['twitter_tags']}\n" unless @twitter_config['twitter_tags'] == ''

    @twitter_config['twitter_users'].each do |user|

      tweets = try { self.get_tweets(user, 'timeline') }

      if @twitter_config['save_favorites']
        favs = try { self.get_tweets(user, 'favorites')}
      else
        favs = ''
      end

      if @twitter_config['save_retweets']
        retweets = try { self.get_tweets(user, 'retweets')}
      else
        retweets = ''
      end

      unless tweets == ''
        tweets = "## Tweets\n\n### Posts by @#{user} on #{Time.now.strftime(@date_format)}\n\n#{tweets}#{tags}"
        sl.to_dayone({'content' => tweets})
      end
      unless favs == ''
        favs = "## Favorite Tweets\n\n### Favorites from @#{user} for #{Time.now.strftime(@date_format)}\n\n#{favs}#{tags}"
        sl.to_dayone({'content' => favs})
      end
      unless  retweets == ''
        retweets = "## Retweets\n\n### Retweets from @#{user} for #{Time.now.strftime(@date_format)}\n\n#{retweets}#{tags}"
        sl.to_dayone({'content' => retweets})
      end
    end
  end

  def try(&action)
    retries = 0
    success = false
    until success || $options[:max_retries] == retries
      result = yield
      if result
        success = true
      else
        @log.error e
        retries += 1
        @log.error("Error performing action, retrying (#{retries}/#{$options[:max_retries]})")
        sleep 2
      end
    end
    result
  end

end

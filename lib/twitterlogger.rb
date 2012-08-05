class TwitterLogger < SocialLogger
  require 'rexml/document'

  def initialize(config = {})
    if config['twitter_users']
      config.each_pair do |att_name, att_val|
        instance_variable_set("@#{att_name}", att_val)
      end
    else
      return false
    end

    @save_images ||= true
    @storage ||= 'icloud'
    @droplr_domain ||= 'd.pr'
    @storage ||= 'icloud'
    @sl = DayOne.new({ 'storage' => @storage })
    # @sl.dayonepath = @storage unless @storage == 'icloud'
    @tags ||= ''
    @tags = "\n\n#{@tags}\n" unless @tags == ''
  end
  attr_accessor :user, :save_images, :droplr_domain, :storage

  def get_body(target, depth = 0)

    final_url = RedirectFollower.new(target).resolve
    url = URI.parse(final_url.url)

    host, port = url.host, url.port if url.host && url.port
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(host, port) {|http| http.request(req) }

    return res.body
  end

  def download_images(images)
    images.each do |image|
      options = {}
      options['content'] = image['content']
      options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip
      path = @sl.save_image(image['url'],options['uuid'])

      @sl.store_single_photo(path,options)
    end
    return true
  end

  def get_tweets(user,type='timeline')
    if type == 'favorites'
      url = URI.parse("http://api.twitter.com/1/favorites.xml?count=200&screen_name=#{user}&include_entities=true&count=200")
    else
      url = URI.parse("http://api.twitter.com/1/statuses/user_timeline.xml?screen_name=#{user}&count=200&exclude_replies=true&include_entities=true")
    end
    tweets = ''
    images = []
    begin
      begin
        res = Net::HTTP.get_response(url).body
      rescue Exception => e
        raise "Failure getting response from Twitter"
        p e
      end
      REXML::Document.new(res).elements.each("statuses/status") { |tweet|
        today = Time.now - (60 * 60 * 24)
        tweet_date = Time.parse(tweet.elements['created_at'].text)
        break if tweet_date < today
        tweet_text = tweet.elements['text'].text.gsub(/\n/,"\n\t")
        tweet_id = tweet.elements['id'].text
        unless tweet.elements['entities/urls'].nil? || tweet.elements['entities/urls'].length == 0
          tweet.elements.each("entities/urls/url") { |url|
            tweet_text.gsub!(/#{url.elements['url'].text}/,"[#{url.elements['display_url'].text}](#{url.elements['expanded_url'].text})")
          }
        end
        begin
        if @save_images
          tweet_images = []
          unless tweet.elements['entities/media'].nil? || tweet.elements['entities/media'].length == 0
            tweet.elements.each("entities/media/creative") { |img|
              tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => img.elements['media_url'].text }
            }
          end

          tweet_text.scan(/\((http:\/\/twitpic.com\/\w+?)\)/).each do |picurl|
            final_url = self.get_body(picurl[0]).match(/"(http:\/\/(\w+).cloudfront.net\/photos\/full\/[^"]+?)"/)
            tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => final_url[1] } unless final_url.nil?
          end
          tweet_text.scan(/\((http:\/\/campl.us\/\w+?)\)/).each do |picurl|
            final_url = self.get_body(picurl[0]).match(/"(http:\/\/pics.campl.us\/f\/c\/.+?)"/)
            tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => final_url[1] } unless final_url.nil?
          end
          tweet_text.scan(/\((http:\/\/#{$droplr_domain}\/\w+?)\)/).each do |picurl|
            final_url = self.get_body(picurl[0]).match(/"(https:\/\/s3.amazonaws.com\/files.droplr.com\/.+?)"/)
            tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => final_url[1] } unless final_url.nil?
          end
          tweet_text.scan(/\((http:\/\/instagr\.am\/\w\/\w+?\/)\)/).each do |picurl|
            final_url = self.get_body(picurl[0]).match(/"(http:\/\/distillery.*?\.instagram\.com\/[a-z0-9_]+\.jpg)"/i)
            tweet_images << { 'content' => tweet_text, 'date' => tweet_date.utc.iso8601, 'url' => final_url[1] } unless final_url.nil?
          end
        end
        rescue Exception => e
          raise "Failure gathering images urls"
          p e
        end
        if tweet_images.empty?
          tweets += "\n* [[#{tweet_date.strftime('%I:%M %p')}](https://twitter.com/#{user}/status/#{tweet_id})] #{tweet_text}"
        else
          images.concat(tweet_images)
        end
      }
      if @save_images && !images.empty?
        begin
          self.download_images(images)
        rescue Exception => e
          raise "Failure downloading images"
          p e
        end
      end
      return tweets
    rescue Exception => e
      puts "Error getting #{type} for #{user}"
      p e
      return ''
    end
  end

  def log_tweets
    @twitter_users.each do |user|
      tweets = self.get_tweets(user,'timeline')
      favs = self.get_tweets(user,'favorites')
      unless tweets == ''
        tweets = "## @#{user} on #{Time.now.strftime('%m-%d-%Y')}\n\n#{tweets}#{@tags}"
        @sl.to_dayone({'content' => tweets})
      end
      unless favs == ''
        favs = "## @#{user} favorites for #{Time.now.strftime('%m-%d-%Y')}\n\n#{favs}#{@tags}"
        @sl.to_dayone({'content' => favs})
      end
    end
  end
end

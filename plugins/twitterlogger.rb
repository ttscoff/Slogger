=begin
Plugin: Twitter Logger
Description: Logs updates and favorites for specified Twitter users
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  twitter_users: [ "handle1" , "handle2", ... ]
  save_images: true
  droplr_domain: d.pr
  twitter_tags: "@social @blogging"
Notes:

=end
config = {
  'description' => [
    'Logs updates and favorites for specified Twitter users',
    'twitter_users should be an array of Twitter usernames, e.g. [ ttscoff, markedapp ]',
    'save_images (true/false) determines weather TwitterLogger will look for image urls and include them in the entry',
    'droplr_domain: if you have a custom droplr domain, enter it here, otherwise leave it as d.pr '],
  'twitter_users' => [],
  'save_images' => true,
  'droplr_domain' => 'd.pr',
  'twitter_tags' => '@social @twitter'
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

    images.each do |image|
      options = {}
      options['content'] = image['content']
      options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip
      sl = DayOne.new
      path = sl.save_image(image['url'],options['uuid'])
      sl.store_single_photo(path,options)
    end

    return true
  end

  def get_tweets(user,type='timeline')
    @log.info("Getting Twitter #{type} for #{user}")
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
          if config['save_images']
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
            tweet_text.scan(/\((http:\/\/#{config['droplr_domain']}\/\w+?)\)/).each do |picurl|
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
        if tweet_images.nil?
          tweets += "\n* [[#{tweet_date.strftime('%I:%M %p')}](https://twitter.com/#{user}/status/#{tweet_id})] #{tweet_text}"
        else
          images.concat(tweet_images)
        end
      }
      if config['save_images'] && images
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

  def do_log
    if config.key?(self.class.name)
        config = @config[self.class.name]
        if !config.key?('twitter_users') || config['twitter_users'] == []
          @log.warn("Twitter users have not been configured, please edit your slogger_config file.")
          return
        end
    else
      @log.warn("Twitter users have not been configured, please edit your slogger_config file.")
      return
    end

    config['save_images'] ||= true
    config['droplr_domain'] ||= 'd.pr'

    sl = DayOne.new
    config['twitter_tags'] ||= ''
    tags = "\n\n#{config['twitter_tags']}\n" unless config['twitter_tags'] == ''

    config['twitter_users'].each do |user|
      tweets = self.get_tweets(user,'timeline')
      favs = self.get_tweets(user,'favorites')
      unless tweets == ''
        tweets = "## @#{user} on #{@timespan.strftime('%m-%d-%Y')}\n\n#{tweets}#{tags}"
        sl.to_dayone({'content' => tweets, 'datestamp' => @timespan })
      end
      unless favs == ''
        favs = "## @#{user} favorites for #{@timespan.strftime('%m-%d-%Y')}\n\n#{favs}#{tags}"
        sl.to_dayone({'content' => favs, 'datestamp' => @timespan })
      end
    end
  end

end

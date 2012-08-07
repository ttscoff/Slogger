=begin
Plugin: RSS Logger
Description: Logs any RSS feed and checks for new posts for the current day
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  rss_feeds: [ "feed url 1" , "feed url 2", ... ]
  markdownify_rss_posts: true
  star_rss_posts: true
  rss_tags: "@social @blogging"
Notes:
  - if found, the first image in the post will be saved as the main image for the entry
  - rss_feeds is an array of feeds separated by commas, a single feed is fine, but it should be inside of brackets `[]`
  - markdownify_rss_posts will convert links and emphasis in the post to Markdown for display in Day One
  - star_rss_posts will create a starred post for new RSS posts
  - rss_tags are tags you want to add to every entry, e.g. "@social @blogging"
=end

config = {
  'rss_feeds' => [],
  'markdownify_rss_posts' => false,
  'star_rss_posts' => false,
  'rss_tags' => '@social @blogging'
}
$slog.register_plugin({ 'class' => 'RSSLogger', 'config' => config })

class RSSLogger < Slogger
  def do_log

    if @config['rss_feeds']
      @feeds = @config['rss_feeds']
    else
      @log.warn("No RSS feeds configured")
    end

    @log.info("Logging rss posts for feeds #{@feeds.join(', ')}")

    @markdownify = @config['markdownify_rss_posts'] || true
    @starred = @config['star_rss_posts'] || true
    @tags = @config['rss_tags'] || ''
    @tags = "\n\n#{@tags}\n" unless @tags == ''

    today = Time.now - (60 * 60 * 24)
    @feeds.each do |rss_feed|
      rss_content = ""
      open(rss_feed) do |f|
        rss_content = f.read
      end

      rss = RSS::Parser.parse(rss_content, false)
      rss.items.each { |item|
        item_date = Time.parse(item.pubDate.to_s)
        if item_date > today
          imageurl = false
          image_match = item.content_encoded.match(/src="(http:.*?\.(jpg|png)(\?.*?)?)"/i)
          imageurl = image_match[1] unless image_match.nil?
          if @markdownify
            content = item.description.markdownify
          else
            content = item.description
          end

          options = {}
          options['content'] = "## [#{item.title}](#{self.permalink(item.link)})\n\n#{content}#{@tags}"
          options['datestamp'] = item.pubDate.utc.iso8601
          options['starred'] = @starred
          options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip
          sl = DayOne.new
          if imageurl
            sl.to_dayone(options) if sl.save_image(imageurl,options['uuid'])
          else
            sl.to_dayone(options)
          end
        else
          break
        end
      }
    end
  end

  def permalink(uri,redirect_count=0)
    max_redirects = 10
    options = {}
    url = URI.parse(uri)
    http = Net::HTTP.new(url.host, url.port)
    begin
      request = Net::HTTP::Get.new(url.request_uri)
      response = http.request(request)
      response['location'].gsub(/\?utm.*/,'')
    rescue
      puts "Error expanding #{uri}"
      uri
    end
  end
end

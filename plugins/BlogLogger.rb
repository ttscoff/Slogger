=begin
Plugin: Blog Logger
Description: Logs individual blog posts for the current timespan using RSS feeds
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  blog_feeds: [ "feed url 1" , "feed url 2", ... ]
  markdownify_posts: true
  star_posts: true
  blog_tags: "#social #blogging"
  full_posts: true
Notes:
  - if found, the first image in the post will be saved as the main image for the entry
  - blog_feeds is an array of feeds separated by commas, a single feed is fine, but it should be inside of brackets `[]`
  - markdownify_posts will convert links and emphasis in the post to Markdown for display in Day One
  - star_posts will star entries created for new posts
  - blog_tags are tags you want to add to every entry, e.g. "#social #blogging"
  - full_posts will try to save the entire text of the post if it's available in the feed
=end

config = {
  'description' => ['Logs individual blog posts for the current timespan using RSS feeds',
                    'blog_feeds is an array of feeds separated by commas, a single feed is fine, but it should be inside of brackets `[]`',
                    'markdownify_posts will convert links and emphasis in the post to Markdown for display in Day One',
                    'star_posts will create a starred post for new RSS posts',
                    'blog_tags are tags you want to add to every entry, e.g. "#social #rss"',
                    'full_posts will try to save the entire text of the post if available in the feed'],
  'blog_feeds' => [],
  'markdownify_posts' => false,
  'star_posts' => false,
  'blog_tags' => '#social #blogging',
  'full_posts' => false
}
$slog.register_plugin({ 'class' => 'BlogLogger', 'config' => config })

class BlogLogger < Slogger
  def do_log
    feeds = []
    if @config.key?(self.class.name)
      @blogconfig = @config[self.class.name]
      if !@blogconfig.key?('blog_feeds') || @blogconfig['blog_feeds'] == []
        @log.warn("Blog feeds have not been configured or a feed is invalid, please edit your slogger_config file.")
        return
      else
        feeds = @blogconfig['blog_feeds']
      end
    else
      @log.warn("Blog feeds have not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging posts for feeds #{feeds.join(', ')}")

    feeds.each do |rss_feed|
      retries = 0
      success = false
      until success
        if parse_feed(rss_feed)
          success = true
        else
          break if $options[:max_retries] == retries
          retries += 1
          @log.error("Error parsing #{rss_feed}, retrying (#{retries}/#{$options[:max_retries]})")
          sleep 2
        end
      end

      unless success
        @log.fatal("Could not parse feed #{rss_feed}")
      end
    end
  end

  def parse_feed(rss_feed)
    markdownify = @blogconfig['markdownify_posts']
    unless (markdownify.is_a? TrueClass or markdownify.is_a? FalseClass)
      markdownify = true
    end
    starred = @blogconfig['star_posts']
    unless (starred.is_a? TrueClass or starred.is_a? FalseClass)
      starred = true
    end
    tags = @blogconfig['blog_tags'] || ''
    tags = "\n\n#{tags}\n" unless tags == ''

    today = @timespan
    begin
      rss_content = ""
      open(rss_feed) do |f|
        rss_content = f.read
      end

      rss = RSS::Parser.parse(rss_content, false)
      rss.items.each { |item|
        item_date = Time.parse(item.date.to_s) + Time.now.gmt_offset
        if item_date > today
          content = ''
          if @blogconfig['full_posts']
            begin
              content = item.content_encoded
            rescue
              content = item.description
            end
          else
            content = item.description rescue ''
          end

          imageurl = false
          image_match = content.match(/src="(http:.*?\.(jpg|png))(\?.*?)?"/i) rescue nil
          imageurl = image_match[1] unless image_match.nil?

          content = content.markdownify if markdownify rescue ''

          options = {}
          options['content'] = "## [#{item.title.gsub(/\n+/,' ').strip}](#{item.link})\n\n#{content.strip}#{tags}"
          options['datestamp'] = item.date.utc.iso8601 rescue item.dc_date.utc.iso8601
          options['starred'] = starred
          options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip
          sl = DayOne.new
          sl.save_image(imageurl,options['uuid']) if imageurl
          sl.to_dayone(options)
        else
          break
        end
      }
    rescue Exception => e
      p e
      return false
    end
    return true
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

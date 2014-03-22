=begin
Plugin: Blog Logger
Version: 2.1
Description: Logs individual blog posts for the current timespan using RSS feeds
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  blog_feeds: [ "feed url 1" , "feed url 2", ... ]
  markdownify_posts: true
  save_image: true
  star_posts: true
  blog_tags: "#social #blogging"
Notes:
  - blog_feeds is an array of feeds separated by commas, a single feed is fine, but it should be inside of brackets `[]`
  - markdownify_posts will convert links and emphasis in the post to Markdown for display in Day One
  - if save_image is true, the first image in the post will be saved as the main image for the entry
  - star_posts will star entries created for new posts
  - get_most_popular (true/false) create a separate entry showing the day's top 5 most tweeted posts from recent entries
  - blog_tags are tags you want to add to every entry, e.g. "#social #blogging"
=end

config = {
  'description' => ['Logs individual blog posts for the current timespan using RSS feeds',
                    'blog_feeds is an array of feeds separated by commas, a single feed is fine, but it should be inside of brackets `[]`',
                    'markdownify_posts (true/false) will convert links and emphasis in the post to Markdown for display in Day One',
                    'star_posts (true/false) will create a starred post for new RSS posts',
                    'get_most_popular (true/false) create a separate entry showing the day\'s top 5 most tweeted posts from recent entries',
                    'blog_tags are tags you want to add to every entry, e.g. "#social #rss"'],
  'blog_feeds' => [],
  'markdownify_posts' => true,
  'save_image' => true,
  'star_posts' => false,
  'get_most_popular' => false,
  'blog_tags' => '#social #blogging'
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
        if parse_feed(rss_feed, retries)
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

  def parse_feed(rss_feed, retries)
    markdownify = @blogconfig['markdownify_posts']
    unless (markdownify.is_a? TrueClass or markdownify.is_a? FalseClass)
      markdownify = true
    end
    starred = @blogconfig['star_posts']
    unless (starred.is_a? TrueClass or starred.is_a? FalseClass)
      starred = true
    end
    tags = @blogconfig['blog_tags'] || ''
    tags = "\n\n(#{tags})\n" unless tags == ''

    today = @timespan
    begin
      rss_content = ""
      open(rss_feed) do |f|
        begin
          rss_content = f.read
        rescue Exception => e
          $stderr.puts "Reading content for #{item.title}"
          $stderr.puts e
        end
      end

      rss = RSS::Parser.parse(rss_content, false)

      if @blogconfig['get_most_popular'] && retries == 0
        @log.info("Checking for most tweeted posts on #{rss.title.content}")
        posts = []
        rss.items.each { |item|
          if item.class == RSS::Atom::Feed::Entry
            title = item.title.content.gsub(/\n+/,' ')
            url = item.link.href
          else
            title = item.title.gsub(/\n+/,' ')
            url = item.link
          end
          count = 0
          begin
            open("http://urls.api.twitter.com/1/urls/count.json?url=#{CGI.escape(url)}") do |f|
              json = JSON.parse(f.read)
              count = json['count']
            end
            posts << {
              'title' => title,
              'url' => url,
              'count' => count
            }
          rescue
            @log.error("Error retrieving Twitter count for #{url}")
          end
        }
        unless posts.empty?
          options = {}
          options['content'] = "## Most Tweeted posts on #{rss.title.content} for #{Time.now.strftime(@date_format)}\n\n"
          posts.sort_by { |post| post['count'] }.reverse[0..5].each {|post|
            options['content'] += "* [#{post['title']}](#{post['url']}) (#{post['count']})\n"
          }
          options['content'] += "\n#{tags}"
          options['datestamp'] = Time.now.utc.iso8601
          options['starred'] = false
          sl = DayOne.new
          sl.to_dayone(options)
        end
      end

      rss.items.each { |item|
        begin
          if item.class == RSS::Atom::Feed::Entry
            item_date = Time.parse(item.updated.to_s) + Time.now.gmt_offset
          else
            item_date = Time.parse(item.date.to_s) + Time.now.gmt_offset
          end
        rescue
          @log.warn("No date information found for posts in #{rss_feed}")
          item_date = Time.now
        end
        if item_date > today
          content = nil

          if item.class == RSS::Atom::Feed::Entry
            begin
              content = item.content.content unless item.content.nil?
              content = item.summary.content if content.nil?
              @log.error("No content field recognized in #{rss_feed}") if content.nil?
            rescue Exception => e
              $stderr.puts "Reading content for #{item.title}"
              $stderr.puts e
              return false
            end
          else
            content = item.description
            @log.error("No content field recognized in #{rss_feed}") if content.nil?
          end

          # if RUBY_VERSION.to_f > 1.9
          #   content = content.force_encoding('utf-8')
          # end

          begin
            imageurl = false
            if @blogconfig['save_image']
              image_match = content.match(/src="(https?:.*?\.(jpg|png|jpeg))(\?.*?)?"/i) rescue nil
              imageurl = image_match[1] unless image_match.nil?
            end

            # can't find a way to truncate partial html without nokogiri or other gems...
            # content = content.truncate_html(10) unless @blogconfig['full_posts']
            content.gsub!(/<iframe.*?src="http:\/\/player\.vimeo\.com\/video\/(\d+)".*?\/iframe>(?:<br\/>)+/,"\nhttp://vimeo.com/\\1\n\n")
            content.gsub!(/<iframe.*?src="http:\/\/www\.youtube\.com\/embed\/(.+?)(\?.*?)?".*?\/iframe>/,"\nhttp://www.youtube.com/watch?v=\\1\n\n")

            content = content.markdownify if markdownify rescue content

            # handle "&nbsp_place_holder;" thing
            content.gsub!(/&nbsp_place_holder;/," ")
          rescue Exception => e
            $stderr.puts "Gathering images for #{item.title}"
            $stderr.puts e
          end

          options = {}

          begin
            if item.class == RSS::Atom::Feed::Entry
              title = item.title.content.gsub(/\n+/,' ')
              link = item.link.href
            else
              title = item.title.gsub(/\n+/,' ')
              link = item.link
            end
          rescue Exception => e
            $stderr.puts "Reading title for #{item.title}"
            $stderr.puts e
          end

          options['content'] = "## [#{title.strip}](#{link.strip})\n\n#{content.strip}#{tags}"
          if !item.date.nil?
            options['datestamp'] = item.date.utc.iso8601
          elsif !item.dc_date.nil?
            options['datestamp'] = item.dc_date.utc.iso8601
          elsif !item.updated.nil?
            options['datestamp'] = item.updated.content.utc.iso8601
          else
            @log.warn("Unable to find proper datestamp")
            options['datestamp'] = Time.now.utc.iso8601
          end
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
      $stderr.puts "Reading posts for #{rss_feed}"
      $stderr.puts e
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

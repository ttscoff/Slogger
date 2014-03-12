=begin
Plugin: FeedLogger
Description: Logs any RSS or Atom feed and checks for new posts for the current day
Author: [masukomi](http://masukomi.org)
Configuration:
  feeds: [ "feed url 1" , "feed url 2", ... ]
  markdownify_posts: true
  star_posts: true
  tags: "#social #blogging"
Notes:
  - if found, the first image in the post will be saved as the main image for the entry
  - atom_feeds is an array of feeds separated by commas, a single feed is fine, but it should be inside of brackets `[]`
  - markdownify_posts will convert links and emphasis in the post to Markdown for display in Day One
  - star_posts will create a starred post for new atom posts
  - atom_tags are tags you want to add to every entry, e.g. "#social #blogging"
=end

require 'feed-normalizer'

config = {
  'description' => ['Logs any feed and checks for new posts for the current day',
                    'feeds is an array of feeds separated by commas, a single feed is fine, but it should be inside of brackets `[]`',
                    'markdownify_posts will convert links and emphasis in the post to Markdown for display in Day One',
                    'star_posts will create a starred post for new posts',
                    'tags are tags you want to add to every entry, e.g. "#social #blogging"'],
  'feeds' => [],
  'markdownify_posts' => true,
  'star_posts' => false,
  'tags' => '#social #blogging'
}
$slog.register_plugin({ 'class' => 'FeedLogger', 'config' => config })

class FeedLogger < Slogger
  def do_log
    feeds = []
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('feeds') || config['feeds'] == []
        @log.warn("Feeds have not been configured or a feed is invalid, please edit your slogger_config file.")
        return
      else
        feeds = config['feeds']
      end
    else
      @log.warn("Feeds have not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging posts for feeds #{feeds.join(', ')}")

    feeds.each do |feed_url|
      retries = 0
      success = false
      until success
        if parse_feed(config, feed_url)
          success = true
        else
          break if $options[:max_retries] == retries
          retries += 1
          @log.error("Error parsing #{feed_url}, retrying (#{retries}/#{$options[:max_retries]})")
          sleep 2
        end
      end

      unless success
        @log.fatal("Could not parse feed #{feed_url}")
      end
    end
  end

  def parse_feed(config, feed_url)
    markdownify = config['markdownify_posts']
    unless (markdownify.is_a? TrueClass or markdownify.is_a? FalseClass)
      markdownify = true
    end
    starred = config['star_posts']
    unless (starred.is_a? TrueClass or starred.is_a? FalseClass)
      starred = true
    end
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    today = @timespan
    begin

      feed = FeedNormalizer::FeedNormalizer.parse open(feed_url)
      feed.entries.each { |entry|
        entry_date = nil
        if (entry.date_published and entry.date_published.to_s.length() > 0)
          entry_date = Time.parse(entry.date_published.to_s)
        elsif (entry.last_updated and entry.last_updated.to_s.length() > 0)
          @log.info("Entry #{entry.title} - no published date found\n\t\tUsing last update date instead.")
          entry_date = Time.parse(entry.last_updated.to_s)
        else
          @log.info("Entry #{entry.title} - no published date found\n\t\tUsing current Time instead.")
          entry_date = Time.now()
        end
        if entry_date > today
          @log.info("parsing #{entry.title} w/ date: #{entry.date_published}")
          imageurl = false
          image_match = entry.content.match(/src="(http:.*?\.(jpg|png)(\?.*?)?)"/i) rescue nil
          imageurl = image_match[1] unless image_match.nil?
          content = ''
          begin
            if markdownify
              content = entry.content.markdownify rescue ''
            else
              content = entry.content rescue ''
            end
          rescue => e
             @log.error("problem parsing content: #{e}")
          end

          options = {}
          options['content'] = "## [#{entry.title.gsub(/\n+/,' ').strip}](#{entry.url})\n\n#{content.strip}#{tags}"
          options['datestamp'] = entry.date_published.utc.iso8601 rescue Time.now.utc.iso8601
          options['starred'] = starred
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

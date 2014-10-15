=begin
Plugin: Goodreads Logger
Version: 1.0
Description: Creates separate entries for books you finished today
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  goodreads_feed: "feedurl"
  goodreads_star_posts: true
  goodreads_save_image: true
  goodreads_tags: "#social #reading"
Notes:
  - goodreads_save_image will save the book cover as the main image for the entry
  - goodreads_feed is a string containing the RSS feed for your read books
  - goodreads_star_posts will create a starred post for new books
  - goodreads_tags are tags you want to add to every entry, e.g. "#social #reading"
=end
require 'rexml/document';
config = {
  'description' => ['goodreads_save_image will save the book cover as the main image for the entry',
                    'goodreads_feed is a string containing the RSS feed for your read books',
                    'goodreads_star_posts will create a starred post for new books',
                    'goodreads_tags are tags you want to add to every entry, e.g. "#social #reading"'],
  'goodreads_feed' => '',
  'goodreads_save_image' => false,
  'goodreads_star_posts' => false,
  'goodreads_tags' => '#social #reading'
}
$slog.register_plugin({ 'class' => 'GoodreadsLogger', 'config' => config })

class GoodreadsLogger < Slogger
#    Debugger.start
  def do_log
    feed = ''
    if @config.key?(self.class.name)
      @grconfig = @config[self.class.name]
      if !@grconfig.key?('goodreads_feed') || @grconfig['goodreads_feed'] == ''
        @log.warn("Goodreads feed has not been configured or is invalid, please edit your slogger_config file.")
        return
      else
        feed = @grconfig['goodreads_feed']
      end
    else
      @log.warn("Goodreads feed has not been configured or is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging read books from Goodreads")

    retries = 0
    success = false
    until success
      if parse_feed(feed)
          success = true
      else
        break if $options[:max_retries] == retries
        retries += 1
        @log.error("Error parsing Goodreads feed, retrying (#{retries}/#{$options[:max_retries]})")
        sleep 2
      end
      unless success
        @log.fatal("Could not parse feed #{feed}")
      end
    end
  end

  def parse_feed(rss_feed)
    markdownify = @grconfig['goodreads_markdownify_posts']
    unless (markdownify.is_a? TrueClass or markdownify.is_a? FalseClass)
      markdownify = false
    end
    starred = @grconfig['goodreads_star_posts']
    unless (starred.is_a? TrueClass or starred.is_a? FalseClass)
      starred = false
    end
    save_image = @grconfig['goodreads_save_image']
    unless (save_image.is_a? TrueClass or save_image.is_a? FalseClass)
      save_image = false
    end

    tags = @grconfig['goodreads_tags'] || ''
    tags = "\n\n(#{tags})\n" unless tags == ''

    begin
      #rss_content = ""

      feed_download_response = Net::HTTP.get_response(URI.parse(rss_feed));
      xml_data = feed_download_response.body;

      doc = REXML::Document.new(xml_data);
      doc.root.each_element('//item') { |item|
        content = ''
        item_date = Time.parse(item.elements['pubDate'].text)
        if item_date > @timespan
          imageurl = false
          #  read items are those where the guid type begins with 'Review'
            #debugger
          #next if !item.elements['guid'].text.start_with?('Review')
          #desc = item.elements['book_description'].cdatas().join
          if save_image
            imageurl = item.elements['book_large_image_url'].cdatas().join rescue false
          end
          content += "* Author: #{item.elements['author_name'].text}\n"
          content += "* My rating: #{item.elements['user_rating'].text} / 5\n" rescue ''
          if item.elements['title'].to_s =~ /CDATA/
            title = item.elements['title'].cdatas().join
          else
            title = item.elements['title'].text
          end
          review = item.elements['user_review'].cdatas().join rescue ''
          if !review.empty?
            content += "* My review:\n\n    #{review}\n" rescue ''
          end
          content = content != '' ? "\n\n#{content}" : ''

          options = {}
          options['content'] = "Finished reading [#{title}](#{item.elements['link'].cdatas().join})#{content}#{tags}"
          options['datestamp'] = Time.parse(item.elements['pubDate'].text).utc.iso8601
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
end

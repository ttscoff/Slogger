=begin
Plugin: TraktLogger
Description: Pull in watched items from Trakt.tv
Author: [Steve Crooks](http://steve.crooks.net)
Configuration:
  trakt_feed: "feed URL"
  trakt_save_image: true
  trakt_tv_tags: "#trakt #tv"
  trakt_movie_tags: "#trakt #movie"
Notes:
  This plugin depends on a VIP subscription to trakt.tv, which enable you to get an RSS
  feed of movies and TV shows that you've watched.
=end

require 'rexml/document';

config = {# description and a primary key (username, url, etc.) required
          'description' => ['trakt_feed is a string containing the RSS feed for your read books',
                            'trakt_save_image will save the media image as the main image for the entry',
                            'trakt_tv_tags are tags you want to add to every TV entry',
                            'trakt_movie_tags are tags you want to add to every movie entry'],
          'trakt_feed' => '',
          'trakt_save_image' => true,
          'trakt_tv_tags' => '#trakt #tv',
          'trakt_movie_tags' => '#trakt #movie'
}

$slog.register_plugin({'class' => 'TraktLogger', 'config' => config})

class TraktLogger < Slogger
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    feed = ''
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('trakt_feed') || config['trakt_feed'] == ''
        @log.warn("TraktLogger has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        feed = config['trakt_feed']
      end
    else
      @log.warn("TraktLogger has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging TraktLogger watched media")

    retries = 0
    success = false
    until success
      if parse_feed(feed, config)
        success = true
      else
        break if $options[:max_retries] == retries
        retries += 1
        @log.error("Error parsing Trakt feed, retrying (#{retries}/#{$options[:max_retries]})")
        sleep 2
      end
      unless success
        @log.fatal("Could not parse feed #{feed}")
      end
    end
  end

  def parse_feed(rss_feed, config)
    save_image = config['trakt_save_image']
    unless save_image.is_a? FalseClass
      save_image = true
    end

    tv_tags = config['trakt_tv_tags'] || ''
    tv_tags = "\n\n#{tv_tags}\n" unless tv_tags == ''

    movie_tags = config['trakt_movie_tags'] || ''
    movie_tags = "\n\n#{movie_tags}\n" unless movie_tags == ''

    begin
      rss_content = ""

      feed_download_response = Net::HTTP.get_response(URI.parse(rss_feed))
      xml_data = feed_download_response.body
      xml_data.gsub!('media:', '') #Fix REXML unhappiness
      doc = REXML::Document.new(xml_data)
      doc.root.each_element('//item') { |item|
        content = ''

        item_date = Time.parse(item.elements['pubDate'].text)

        if item_date > @timespan
          title = item.elements['title'].text

          # is this tv or movie?
          is_tv = title.match(/ \d+x\d+ /) ? true : false
          tags = is_tv ? tv_tags : movie_tags

          imageurl = save_image ? item.elements['content'].attributes.get_attribute("url").value : false

          description = item.elements['description'].text rescue ''
          description.sub!(/^.*<br><br>/, "")

          content += "\n\n#{description}" rescue ''
          options = {}
          header = "## Watched A #{is_tv ? 'TV Show' : 'Movie'}\n"
          options['content'] = "#{header}[#{title.gsub(/\n+/, ' ').strip}](#{item.elements['link'].text.strip})#{content}#{tags}"

          options['datestamp'] = item_date.utc.iso8601
          options['uuid'] = %x{uuidgen}.gsub(/-/, '').strip
          sl = DayOne.new
          if imageurl
            sl.to_dayone(options) if sl.save_image(imageurl, options['uuid'])
          else
            sl.to_dayone(options)
          end
        else
          break
        end
      }
    rescue Exception => e
      @log.error("BOOM: #{e}")
      p e
      return false
    end

    true
  end
end

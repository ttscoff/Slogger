=begin
Plugin: Flickr Logger
Description: Logs today's photos from Flickr RSS feed. Get your Flickr ID at <http://idgettr.com/>
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  flickr_ids: [flickr_id1[, flickr_id2...]]
  flickr_tags: "#social #photo"
Notes:
  - This version uses the RSS feed. This can take up to four hours to update, which is why I wrote the default API version. I'm impatient
=end
config = {
  'description' => ['flickr_ids should be an array with one or more Flickr user ids (http://idgettr.com/)']
  'flickr_ids' => [],
  'flickr_tags' => '#social #photo'
}
$slog.register_plugin({ 'class' => 'FlickrLogger', 'config' => config })

require 'rexml/document'

class FlickrLogger < Slogger

  # download images to local files and create day one entries
  # images is an array of hashes: { 'content' => 'photo title', 'date' => 'iso8601 date', 'url' => 'source url' }
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

  def do_log
    if config.key?(self.class.name)
        config = @config[self.class.name]
        if !config.key?('flickr_ids') || config['flickr_ids'] == []
          @log.warn("Flickr users have not been configured, please edit your slogger_config file.")
          return
        end
    else
      @log.warn("Flickr users have not been configured, please edit your slogger_config file.")
      return
    end

    sl = DayOne.new
    config['flickr_tags'] ||= ''
    tags = "\n\n#{config['flickr_tags']}\n" unless config['flickr_tags'] == ''

    @log.info("Getting Flickr images for #{config['flickr_ids'].join(', ')}")
    url = URI.parse("http://api.flickr.com/services/feeds/photos_public.gne?ids=#{config['flickr_ids'].join(',')}")

    begin
      begin
        res = Net::HTTP.get_response(url).body
      rescue Exception => e
        raise "Failure getting response from Flickr"
        p e
      end
      images = []
      REXML::Document.new(res).elements.each("feed/entry") { |photo|
        today = @timespan
        photo_date = Time.parse(photo.elements['published'].text)
        break if photo_date < today
        content = "## " + photo.elements['title'].text
        url = photo.elements['link'].text
        content += "\n\n" + photo.elements['content'].text.markdownify unless photo.elements['content'].text == ''
        images << { 'content' => content, 'date' => photo_date.utc.iso8601, 'url' => url }
      }
    rescue Exception => e
      puts "Error getting photos for #{config['flickr_ids'].join(', ')}"
      p e
      return ''
    end
    if images.length == 0
      @log.info("No new Flickr images found")
      return ''
    else
      @log.info("Found #{images.length} images")
    end

    begin
      self.download_images(images)
    rescue Exception => e
      raise "Failure downloading images"
      p e
    end
  end
end

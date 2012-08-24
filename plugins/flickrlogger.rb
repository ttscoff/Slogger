=begin
Plugin: Flickr Logger
Description: Logs today's photos from Flickr.
Notes:
  Get your Flickr ID at <http://idgettr.com/>
  Get your Flickr API key at <http://www.flickr.com/services/apps/create/noncommercial/>
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  flickr_api_key: 'XXXXXXXXXXXXXXXXXXXXXXXXX'
  flickr_ids: [flickr_id1[, flickr_id2...]]
  flickr_tags: "@social @photo"
Notes:

=end
config = {
  'flickr_description' => [
    'Logs today\'s photos from Flickr.',
    'Get your Flickr ID at <http://idgettr.com/>',
    'Get your Flickr API key at <http://www.flickr.com/services/apps/create/noncommercial/>'],
  'flickr_api_key' => '',
  'flickr_ids' => [],
  'flickr_tags' => '@social @photo'
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
    today = @timespan.to_i

    @log.info("Getting Flickr images for #{config['flickr_ids'].join(', ')}")
    images = []
    begin
      config['flickr_ids'].each do |user|

        open("http://www.flickr.com/services/rest/?method=flickr.people.getPublicPhotos&api_key=#{config['flickr_api_key']}&user_id=#{user}&extras=description,date_upload,url_m&per_page=15") { |f|
            REXML::Document.new(f.read).elements.each("rsp/photos/photo") { |photo|
              photo_date = photo.attributes["dateupload"].to_s
              break unless Time.at(photo_date.to_i) > @timespan
              url = photo.attributes["url_m"]
              content = "## " + photo.attributes['title']
              content += "\n\n" + photo.attributes['content'] unless photo.attributes['content'].nil?
              images << { 'content' => content, 'date' => Time.at(photo_date.to_i).utc.iso8601, 'url' => url }
            }
        }
      end

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

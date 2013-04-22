=begin
Plugin: Flickr Logger
Version: 1.0
Description: Logs today's photos from Flickr.
Notes:
  Get your Flickr ID at <http://idgettr.com/>
  Get your Flickr API key at <http://www.flickr.com/services/apps/create/noncommercial/>
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  flickr_api_key: 'XXXXXXXXXXXXXXXXXXXXXXXXX'
  flickr_ids: [flickr_id1[, flickr_id2...]]
  flickr_tags: "#social #photo"
Notes:

=end
config = {
  'flickr_description' => [
    'Logs today\'s photos from Flickr.',
    'flickr_ids is an array of one or more IDs',
    'flickr_datetype can be the "upload" or "taken" date that has tpo be used',
    'Get your Flickr ID at <http://idgettr.com/>',
    'Get your Flickr API key at <http://www.flickr.com/services/apps/create/noncommercial/>'],
  'flickr_api_key' => '',
  'flickr_ids' => [],
  'flickr_datetype' => 'upload',
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
      options['datestamp'] = image['date']
      sl = DayOne.new
      path = sl.save_image(image['url'],options['uuid'])
      sl.store_single_photo(path,options) unless path == false
    end

    return true
  end

  def do_log
    if @config.key?(self.class.name)
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
    tags = config['flickr_tags'] == '' ? '' : "\n\n#{config['flickr_tags']}\n"
    today = @timespan.to_i

    @log.info("Getting Flickr images for #{config['flickr_ids'].join(', ')}")
    images = []
    begin
      config['flickr_ids'].each do |user|
        open("http://www.flickr.com/services/rest/?method=flickr.people.getPublicPhotos&api_key=#{config['flickr_api_key']}&user_id=#{user}&extras=description,date_upload,date_taken,url_m&per_page=15") { |f|
            REXML::Document.new(f.read).elements.each("rsp/photos/photo") { |photo|
              if config.key?('flickr_datetype') && config['flickr_datetype'] == 'taken'
                # import images in dayone using the date/time when the photo was taken
                photo_date = photo.attributes["datetaken"].to_s
                photo_date = DateTime.now
                # compensate for current timezone (will not compensate for DST, because it takes the current system timezone)
                zone = photo_date.zone
                photo_date = DateTime.parse(photo.attributes["datetaken"] + zone)
                photo_date = photo_date.strftime('%s').to_s
                break unless Time.at(photo_date.to_i).utc > @timespan.utc
                image_date = Time.at(photo_date.to_i).utc.iso8601
              else
                # import images in dayone using the date/time when the photo was taken
                photo_date = photo.attributes["dateupload"].to_s
                break unless Time.at(photo_date.to_i) > @timespan
                image_date = Time.at(photo_date.to_i).utc.iso8601
              end
              url = photo.attributes["url_m"]
              content = "## " + photo.attributes['title']
              content += "\n\n" + photo.attributes['content'] unless photo.attributes['content'].nil?
              content += tags
              images << { 'content' => content, 'date' => image_date, 'url' => url }
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

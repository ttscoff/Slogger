=begin
Plugin: SoundCloud Logger
Description: Logs SoundCloud uploads as a digest
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  soundcloud_id: 20678639
  soundcloud_starred: false
  soundcloud_tags: "#social #music"
Notes:
  - soundcloud_id is a string of numbers representing your user ID.
  - There may be an easier way to find this, but you can go to your Dashboard -> Tracks,
  - view the page source in your browser and search for "trackOwnerId"
  - soundcloud_starred is true or false, determines whether SoundCloud uploads are starred entries
  - soundcloud_tags are tags you want to add to every SoundCloud entry, e.g. "#social #music"
=end

config = {
  'description' => ['Logs SoundCloud uploads as a digest',
                    'soundcloud_id is a string of numbers representing your user ID',
                    'Dashboard -> Tracks, view page source and search for "trackOwnerId"',
                    'soundcloud_starred is true or false, determines whether SoundCloud uploads are starred entries',
                    'soundcloud_tags are tags you want to add to every SoundCloud entry, e.g. "#social #music"'],
  'soundcloud_id' => '',
  'soundcloud_starred' => false,
  'soundcloud_tags' => '#social #music'
}
$slog.register_plugin({ 'class' => 'SoundCloudLogger', 'config' => config })

class SoundCloudLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      @scconfig = @config[self.class.name]
      if !@scconfig.key?('soundcloud_id') || @scconfig['soundcloud_id'] == [] || @scconfig['soundcloud_id'].nil?
        @log.warn("SoundCloud logging has not been configured or a feed is invalid, please edit your slogger_config file.")
        return
      else
        user = @scconfig['soundcloud_id']
      end
    else
      @log.warn("SoundCloud logging not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging SoundCloud uploads")

    retries = 0
    success = false

    until success
      if parse_feed("http://api.soundcloud.com/users/#{user}/tracks?limit=25&offset=0&linked_partitioning=1&secret_token=&client_id=ab472b80bdf8389dd6f607a10abfe33b&format=xml")
        success = true
      else
        break if $options[:max_retries] == retries
        retries += 1
        @log.error("Error parsing SoundCloud feed for user #{user}, retrying (#{retries}/#{$options[:max_retries]})")
        sleep 2
      end
    end

    unless success
      @log.fatal("Could not parse SoundCloud feed for user #{user}")
    end

  end

  def parse_feed(rss_feed)
    tags = @scconfig['soundcloud_tags'] || ''
    tags = "\n\n#{tags}\n" unless tags == ''
    starred = @scconfig['soundcloud_starred'] || false

    begin
      rss_content = ""

      feed_download_response = Net::HTTP.get_response(URI.parse(rss_feed));
      xml_data = feed_download_response.body;

      doc = REXML::Document.new(xml_data);
      # Useful SoundCloud XML elements
      # created-at
      # permalink-url
      # artwork-url
      # title
      # description
      content = ''
      doc.root.each_element('//track') { |item|
        item_date = Time.parse(item.elements['created-at'].text)
        if item_date > @timespan
          content += "* [#{item.elements['title'].text}](#{item.elements['permalink-url'].text})\n" rescue ''
          desc = item.elements['description'].text
          content += "\n     #{desc}\n" unless desc.nil? or desc == ''
        else
          break
        end
      }
      unless content = ''
        options = {}
        options['content'] = "## SoundCloud uploads\n\n#{content}#{tags}"
        options['starred'] = starred
        sl = DayOne.new
        sl.to_dayone(options)
      end
    rescue Exception => e
      p e
      return false
    end
    return true
  end
end

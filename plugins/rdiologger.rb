=begin
Plugin: Rdio Logger
Description: Logs summary of activity on Rdio for the specified user
Author: [Julien Grimault](github.com/juliengrimault)
Configuration:
  rdio_username: juliengrimault
Notes:
  - multi-line notes with additional description and information (optional)
=end

config = {
  'description' => ['Logs tracks/albums added to your rdio collection.', 'rdio_username should be the Rdio username. include_album_image determines wether the album image is included in the journal entry'],
  'rdio_username' => '',
  'include_album_image' => true,
  'tags' => '#social #music'
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'RdioLogger', 'config' => config })

require 'rdio_api'
class RdioLogger < Slogger
  RDIO_LOGGER_TABLE_WIDTH = 3
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log

    unless logger_registered?
      @log.warn("Rdio logger was not registered, please edit your slogger_config file.")
      return
    end

    unless logger_configured?
      @log.warn("Rdio user has not been configured or an option is invalid, please edit your slogger_config file.")
      return
    end

    @log.info("Logging Rdio activity for #{logger_config['rdio_username']}")
    
    
    userKey = try { next get_user_key() }
    return nil unless userKey
    
    activities = try { next get_activities(userKey) }
    return nil unless activities && activities.count > 0

    albums = get_albums(activities)
    content = generate_content(albums)

    sl = DayOne.new
    sl.to_dayone({ 'content' => "Rdio Activity - Album#{albums.count > 1 ? "s" : ""} added to collection\n#{content}\n\n#{tags}"})
  end

private
  def logger_registered?
    @config.key?(self.class.name)
  end

  def logger_configured?
    logger_config.key?('rdio_username') && logger_config['rdio_username'] != ''
  end

  def logger_config
    @config[self.class.name]
  end

    def rdio
    @rdio ||= RdioApi.new(:consumer_key => 'xxh3fr2p2s9xu9ps4b7gj888', :consumer_secret => 'ckwHAXrAkK')
  end
  
  def tags
    logger_config['tags'] || ''
  end
  
  def try(&action)
    retries = 0
    success = false
    until success || $options[:max_retries] == retries
      begin
        result = yield
        success = true
      rescue => e
        @log.error e
        retries += 1
        @log.error("Error performing action, retrying (#{retries}/#{$options[:max_retries]})")
        sleep 2
      end
    end
    result  
  end

  def get_user_key
    user = rdio.findUser(:vanityName => logger_config['rdio_username'])
    return nil unless user
    user['key']
  end
  
  def get_activities(userKey)
    response = rdio.getActivityStream(:user => userKey, :scope => "user")
    return nil unless response
    response['updates'].select { |item| is_activity_valid?(item) }
  end
  
  def is_activity_valid?(activity)
    activity['update_type'] == 0 && Time.parse(activity['date']) > @timespan
  end

  def get_albums(activities)
    activities.reduce([]) { |result, activity| result.concat(activity['albums']) }
  end
  
  def generate_content(albums)
    if logger_config['include_album_image']
      generate_table_content(albums)
    else
      generate_text_content(albums)
    end
  end

  def generate_table_content(albums)
    result = ""
    albums.each_with_index do |album, i|
      result += generate_entry_with_image(album) + table_separator(i)    
    end
    result
  end

  def table_separator(index)
    if end_of_row?(index)
        seperator = "\n"
        if end_of_first_row?(index)
          seperator += table_header_md + "\n"
        end
      else
        seperator = " | "
      end
      seperator
  end

  def end_of_row?(index)
    (index + 1) % RDIO_LOGGER_TABLE_WIDTH == 0
  end

  def end_of_first_row?(index)
    (index + 1) == RDIO_LOGGER_TABLE_WIDTH
  end

  def table_header_md
    Array.new(RDIO_LOGGER_TABLE_WIDTH, ":-------:").join(" | ")
  end

  def generate_entry_with_image(album)
    link_text = "#{album['artist']} - #{album['name']}"
    link_text.gsub!(/[()]/, "-") #replace parentheses with - otherwise it conflict with the md

    if link_text.length > 50 #limit the length of the text in the table otherwise the layout is not balanced
      link_text = link_text[0..50] + "..."
    end
    
    url = album['shortUrl']
    "![alt text](#{album['icon']})#{md_link(link_text, url)}"
  end

  def generate_text_content(albums)
    albums.reduce("") { |result, album| result + generate_entry_with_text(album) }
  end

  def generate_entry_with_text(album)
    link_text = "#{album['artist']} - #{album['name']}"
    url = album['shortUrl']
    md_link(link_text,url)
  end

  def md_link(text, url)
    "[#{text}](#{url})"
  end
end

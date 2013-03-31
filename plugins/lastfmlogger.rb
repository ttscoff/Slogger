=begin
Plugin: Last.fm Logger
Description: Logs playlists and loved tracks for the day
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  lastfm_user: lastfmusername
  lastfm_tags: "#social #blogging"
Notes:

=end
config = {
  'lastfm_description' => ['Logs songs scrobbled for time period.','lastfm_user is your Last.fm username.'],
  'lastfm_user' => '',
  'lastfm_feeds' => ['recent', 'loved'],
  'lastfm_tags' => '#social #music'
}
$slog.register_plugin({ 'class' => 'LastFMLogger', 'config' => config })

class LastFMLogger < Slogger

  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('lastfm_user') || config['lastfm_user'] == ''
        @log.warn("Last.fm has not been configured, please edit your slogger_config file.")
        return
      else
        feeds = config['feeds']
      end
    else
      @log.warn("Last.fm has not been configured, please edit your slogger_config file.")
      return
    end

    config['lastfm_tags'] ||= ''
    tags = "\n\n#{config['lastfm_tags']}\n" unless config['lastfm_tags'] == ''

    config['lastfm_feeds'] ||= ['recent', 'loved']

    feeds = []
    feeds << {'title'=>"## Listening To", 'feed' => "http://ws.audioscrobbler.com/2.0/user/#{config['lastfm_user']}/recenttracks.rss?limit=100"} if config['lastfm_feeds'].include?('recent')
    feeds << {'title'=>"## Loved Tracks", 'feed' => "http://ws.audioscrobbler.com/2.0/user/#{config['lastfm_user']}/lovedtracks.rss?limit=100"} if config['lastfm_feeds'].include?('loved')

    today = @timespan

    @log.info("Getting Last.fm playists for #{config['lastfm_user']}")

    feeds.each do |rss_feed|
      entrytext = ''
      rss_content = ""
      begin
        feed_url = URI.parse(rss_feed['feed'])
        feed_url.open do |f|
          rss_content = f.read
        end
      rescue Exception => e
        raise "ERROR fetching feed #{rss_feed['title']}"
        p e
      end
      content = ''
      rss = RSS::Parser.parse(rss_content, false)
      
      # define a hash to store song count and a hash to link song title to the last.fm URL
	  songs_count = {}
	  title_to_link = {}

      rss.items.each { |item|
        break if Time.parse(item.pubDate.to_s) < today
        title = String(item.title).e_link()
        link = String(item.link).e_link()

		# keep track of URL for each song title
        title_to_link[title] = link

        # store play counts in hash
		if songs_count[title].nil?
			songs_count[title] = 1
		else
			songs_count[title] += 1
		end
      }
      
      # loop over each song and make final output as appropriate
	  # (depending on whether there was 1 play or more)	      
      songs_count.each { |k, v| 

        # a fudge because I couldn't seem to access this hash value directly in
        # the if statement
      	link = title_to_link[k]

		if v == 1
        	content += "* [#{k}](#{link})\n"
		else
        	content += "* [#{k}](#{link}) (#{v} plays)\n"
		end
      	}

      if content != ''
        entrytext = "#{rss_feed['title']} for #{today.strftime(@date_format)}\n\n" + content + "\n#{tags}"
      end
      DayOne.new.to_dayone({'content' => entrytext}) unless entrytext == ''
    end
  end
end

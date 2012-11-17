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

    feeds = [{'title'=>"## Listening To", 'feed' => "http://ws.audioscrobbler.com/2.0/user/#{config['lastfm_user']}/recenttracks.rss?limit=100"},{'title'=>"## Loved Tracks", 'feed' => "http://ws.audioscrobbler.com/2.0/user/#{config['lastfm_user']}/lovedtracks.rss?limit=100"}]


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
      rss.items.each { |item|
        break if Time.parse(item.pubDate.to_s) < today
        title = String(item.title).e_link()
        link = String(item.link).e_link()
        content += "* [#{title}](#{link})\n"
      }
      if content != ''
        entrytext = "#{rss_feed['title']} for #{today.strftime('%m-%d-%Y')}\n\n" + content + "\n#{tags}"
      end
      DayOne.new.to_dayone({'content' => entrytext}) unless entrytext == ''
    end
  end
end

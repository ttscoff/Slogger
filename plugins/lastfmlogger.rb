=begin
Plugin: Last.fm Logger
Description: Logs playlists and loved tracks for the day
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  lastfm_user: lastfmusername
  lastfm_tags: "@social @blogging"
Notes:

=end
config = {
  'lastfm_user' => '',
  'lastfm_tags' => '@social @music'
}
$slog.register_plugin({ 'class' => 'RSSLogger', 'config' => config })

class LastFMLogger < Slogger

  def do_log
    if @config['lastfm_user']
      @user = @config['lastfm_user']
    else
      @log.warn("No Twitter user(s) configured")
      return false
    end
    @config['lastfm_tags'] ||= ''
    @tags = "\n\n#{@config['lastfm_tags']}\n" unless @config['lastfm_tags'] == ''
    @debug = @config['debug'] || false
    @feeds = [{'title'=>"## Listening To", 'feed' => "http://ws.audioscrobbler.com/2.0/user/#{@config['lastfm_user']}/recenttracks.rss"},{'title'=>"## Loved Tracks", 'feed' => "http://ws.audioscrobbler.com/2.0/user/#{@config['lastfm_user']}/lovedtracks.rss"}]
    @storage = config['storage'] || 'icloud'
    @sl = DayOne.new({ 'storage' => @storage })
    @today = Time.now - (60 * 60 * 24)

    @log.info("Getting Last.fm playists for #{@config['lastfm_user']}")

    @feeds.each do |rss_feed|
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
        break if Time.parse(item.pubDate.to_s) < @today
        content += "* [#{item.title}](#{item.link})\n"
      }
      if content != ''
        entrytext = "#{rss_feed['title']} for #{@today.strftime('%m-%d-%Y')}\n\n" + content + "\n#{@tags}"
      end
      DayOne.new.to_dayone({'content' => entrytext}) unless entrytext == ''
    end
  end
end

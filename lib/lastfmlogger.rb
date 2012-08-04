=begin
Checks last.fm feed once a day for that day's posts. You can specify multiple
feeds to parse in the feeds array.
=end
class LastFMLogger < SocialLogger

  def initialize(config = {})
    if config['user']
      @user = config['user']
    else
      return false
    end
    @tags ||= ''
    @tags = "\n\n#{@tags}\n" unless @tags == ''
    @debug = config['debug'] || false
    @feeds = [{'title'=>"## Listening To", 'feed' => "http://ws.audioscrobbler.com/2.0/user/#{@user}/recenttracks.rss"},{'title'=>"## Loved Tracks", 'feed' => "http://ws.audioscrobbler.com/2.0/user/#{@user}/lovedtracks.rss"}]
    @storage = config['storage'] || 'icloud'
    @sl = DayOne.new({ 'storage' => @storage })
    @today = Time.now - (60 * 60 * 24)
  end
  attr_accessor :user, :feeds, :debug

  def log_lastfm
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
      @sl.to_dayone({'content' => entrytext}) unless entrytext == ''
    end
  end
end

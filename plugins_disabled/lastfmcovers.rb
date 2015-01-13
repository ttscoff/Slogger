=begin
Plugin: Last.fm Logger with Covers
Version: 1.5
Description: Logs playlists and loved tracks for a time period. 
Author: Based on Last.fm Logger by[Brett Terpstra](http://brettterpstra.com) with additions by [Micah Cooper](http://www.meebles.org)
Configuration:
  lastfm_user: lastfmusername
  lastfm_tags: "#social #blogging"
Notes:
- added timestamps option
=end

#require 'rubyvis'
require 'rmagick'
include Magick

config = {
  'lastfm_description' => [
    'Logs songs scrobbled for time period.',
    'lastfm_user is your Last.fm username.',
    'lastfm_feeds is an array that determines whether it grabs recent tracks, loved tracks, or both',
    'lastfm_include_timestamps (true/false) will add a timestamp prefix based on @time_format to each song'
  ],
  'lastfm_include_timestamps' => false,
  'lastfm_user' => '',
  'lastfm_covers' => true,
  'lastfm_chunk' => '', # default does since last run in one chunk, but I like to do longer period carved into dailies
  'lastfm_feeds' => ['recent', 'loved'],
  'lastfm_tags' => '#social #music'
}
$slog.register_plugin({ 'class' => 'LastFMLogger', 'config' => config })

class LastFMLogger < Slogger
  def get_fm_feed(feed)
    begin
      rss_content = false
      feed_url = URI.parse(feed)
      feed_url.open do |f|
        rss_content = f.read
      end
      return rss_content
    rescue
      return false
    end
  end

  def processEntries(startDate, endDate, songCollection)
    dailyCollectionStart = songCollection.find_all {|i| startDate < i['dateTime']  }
    dailyCollection = dailyCollectionStart.find_all {|i| i['dateTime'] < endDate}

    #puts 'dailyCollection: ' + dailyCollection.to_s



  end

  def idSong (artist, trackname, mbid)
    songtags = []

    if (mbid != nil)
      feed = "http://ws.audioscrobbler.com/2.0/?method=track.getTopTags&api_key=fbee9ce3df6a36fd7af925f4951d2421&mbid=#{mbid}"
      
    else
      tmpfeed = "http://ws.audioscrobbler.com/2.0/?method=track.getTopTags&api_key=fbee9ce3df6a36fd7af925f4951d2421&artist=#{artist}&track=#{trackname}"
      feed = URI.escape(tmpfeed)
    end
    #puts 'feed: ' + feed

    xml_data = Net::HTTP.get_response(URI.parse(feed)).body
    doc = REXML::Document.new(xml_data)

    #puts doc

    #doc.elements.each("toptags") do |ele|  
    doc.elements.each("lfm/toptags/tag") do |ele|  
      songtag = ele.get_text("name").to_s
      #tagcount = ele.get_text("count").to_s
      if songtag != nil
        songtags.push(songtag)
      end
      #puts ele.to_s

      #puts 'tag: ' + songtag + " at " + tagcount
    end

    return songtags

  end

  

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
    tags = "\n\n(#{config['lastfm_tags']})\n" unless config['lastfm_tags'] == ''

    config['lastfm_feeds'] ||= ['recent', 'loved']

    feeds = []
    feeds << {'title'=>"Listening To", 'feed' => "recenttracks"} if config['lastfm_feeds'].include?('recent')
    feeds << {'title'=>"Loved Tracks", 'feed' => "lovedtracks"} if config['lastfm_feeds'].include?('loved')
    
    startdate = @timespan.to_i

    @log.info("Getting Last.fm playlists for #{config['lastfm_user']}")

    # With thanks to Ben Foxall https://gist.github.com/benfoxall/7976631
    page = 0
    total = 1 # set properly by response
    key = 'e38cc7822bd7476fe4083e36ee69748e' # set to your own
    today = @timespan

    feeds.each do |rss_feed|
      done = 0
      songCollection = []

      while ((page < total) && (done != 1))

        url = "http://ws.audioscrobbler.com/2.0/?method=user.get#{rss_feed['feed']}&user=#{config['lastfm_user']}&api_key=#{key}&limit=200&page=#{page}"
        puts url
        xml_data = Net::HTTP.get_response(URI.parse(url)).body
        doc = REXML::Document.new(xml_data)

        doc.elements.each("lfm/#{rss_feed['feed']}/track") do |ele|  
          
          begin
            utsObj = ele.elements['date'].attributes
            utsNum = utsObj['uts'].to_i
          rescue # if we're currently playing a song, we might have problems
            utsNum = Time.now.utc.to_i
          end
          utsDateTime = utsNum

          if utsDateTime < startdate
            done = 1
            break
          end
          

          artist = ele.get_text('artist')
          trackname = ele.get_text('trackname')
          mbid = ele.get_text('mbid')

          if config['lastfm_covers']
            smallCover = REXML::XPath.first(ele, "image[@size='small']").text.to_s
            mediumCover = REXML::XPath.first(ele, "image[@size='medium']").text.to_s
            largeCover = REXML::XPath.first(ele, "image[@size='large']").text.to_s
            extralargeCover = REXML::XPath.first(ele, "image[@size='extralarge']").text.to_s
          else
            smallCover = nil
            mediumCover = nil
            largeCover = nil
            extralargeCover = nil
          end

          songtags = idSong(artist, trackname, mbid)

          songHash = {
            "dateTime" => utsDateTime,
            "txtdate" => ele.get_text('date'), 
            "artist" => ele.get_text('artist').to_s, 
            "album" => ele.get_text('album').to_s,
            "trackname" => ele.get_text('name').to_s,
            "trackurl" => ele.get_text('url').to_s,
            "mbid" => ele.get_text('mbid').to_s, #musicbrainz id
            "songtags" => songtags,
            "smallCover" => smallCover,
            "mediumCover" => mediumCover,
            "largeCover" => largeCover,
            "extralargeCover" => extralargeCover }          

          songCollection.push(songHash)

        end # xml parsing
        begin
          total = doc.elements.each("lfm/#{rss_feed['feed']}") {|t| t}.first.attributes['totalPages'].to_i
        rescue
          total = 0
        end

        page += 1
      end # page while loop

      # unpleasant way to split entire collection into daily intervals
      if config['lastfm_chunk'] == 'daily'
        nowTime = Time.now.utc.to_i
        targetDate = @timespan.to_i
        periodDays = 1
      elsif config['lastfm_chunk'] == 'weekly'
        nowTime = Time.now.utc.to_i
        targetDate = @timespan.to_i
        periodDays = 7
      else
        nowTime = Time.now.utc.to_i
        targetDate = @timespan.to_i
        periodDays = 99999 # a hack :( but should restore default behavior
      end

      while (targetDate < nowTime) do
        endDate = targetDate + 60 * 60 * 24 * periodDays
        dailyCollection = processEntries(targetDate, endDate, songCollection)  
        targetDate = endDate

        # define a hash to store song count and a hash to link song title to the last.fm URL
        songs_count = {}
        title_to_link = {}
        content = ''

        if !dailyCollection
          break
        end

        dailyTags = [] # will store all of the song tags for the day
        dailyAlbums = [] # store all of the album names for the day

        dailyCollection.each { |item|
          timestamp = Time.parse(Time.at(item['dateTime']).to_s)
          ts = config['lastfm_include_timestamps'] ? "#{timestamp.strftime(@time_format)} | " : ""
          artistTrack = ''
          if item['artist']
            artistTrack = item['artist'] + ' — ' + item['trackname'] 
          else
            artistTrack = item['trackname']
          end
          title = ts + String(artistTrack).e_link()

          link = String(item['trackurl']).e_link()

          # keep track of URL for each song title
          title_to_link[title] = link

          # store play counts in hash
          if songs_count[title].nil?
            songs_count[title] = 1
          else
            songs_count[title] += 1
          end

          songtags = item['songtags']
          songtags.each { |tag|
            dailyTags.push(tag)
          }
          thisAlbum = item['extralargeCover']
          dailyAlbums.push(thisAlbum)
        }

        dailyTagsCounted = Hash.new (0)
        dailyTags.each do |v|
          dailyTagsCounted[v] += 1
        end

    
        albumsCounted = Hash.new (0)
        albumNum = 0
        dailyAlbums.each do |v|
          albumsCounted[v] += 1
          albumNum += 1
        end

        albumNum = albumsCounted.length
        uimage = nil
        if albumNum > 0        
          tileX = Math.sqrt(albumNum).floor # how many images do we have across
          if tileX == 0
            tileX =1
          end
          tileY = (albumNum / tileX).floor
          maxTiles = tileX * tileY # get rid of straggler tiles!
          marginsBetween = 10 # gap between images

          d1maxwidth = 2100 - (tileX * marginsBetween) # reduce the max image size by the total of our images
          idvlMaxWidth = (d1maxwidth / tileX).floor # how wide can each image be?

          # I feel a montage coming on
          images = ImageList.new()
          albumsCounted.take(maxTiles).each do |cover|
            begin
              image = Magick::ImageList.new 
              urlimage = open(cover[0])
              image.from_blob(urlimage.read)
              thumb = image.resize_to_fit(idvlMaxWidth, idvlMaxWidth)
              images << thumb
              thumb.write('thumb.jpg')
            rescue
            end
          end

          background = '#000000'

          columns = tileX
          rows = tileY
          begin
            collage = images.montage {
              self.geometry = '+' + (marginsBetween/2).to_s + '+' + (marginsBetween/2).to_s
              self.tile = columns.to_s + 'x' + rows.to_s
              self.background_color = background
            }
            collage.format = "JPG"
            uimage = collage
          rescue
            uimage = nil
          end
        end

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

        tags = config['lastfm_tags'] || ''
        tags = tags.scan(/#([A-Za-z0-9]+)/m).map { |tag| tag[0].strip }.delete_if {|tag| tag =~ /^\d+$/ }.uniq.sort

        if content != ''
          endTimeStamp = Time.at(endDate)
          options = {}
          options['content'] = content
          options['datestamp'] = endTimeStamp.utc.iso8601
          options['starred'] = false
          options['tags'] = tags
          uuid = %x{uuidgen}.gsub(/-/,'').strip
          options['uuid'] = uuid
          img_name = @dayonepath+"/photos/#{uuid}.jpg"
          if uimage
            uimage.write(img_name)
          end

          sl = DayOne.new
          sl.to_dayone(options) 

        end
      end
    end # feed iteration

  end # do_log

end # whole shebang (wait, that's shell scripts)
        


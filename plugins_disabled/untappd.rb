=begin
Plugin: Untappd
Description: Query activity from untappd.com
Author: [Jon Nall](http://github.com/nall)
Configuration:
  untappd_user: ""
  untappd_client_id: ""
  untappd_client_secret: ""
Notes:
  - multi-line notes with additional description and information (optional)
=end

require 'untappd'

config = { # description and a primary key (username, url, etc.) required
  'description' => ['Logs untappd checkins',
                    'untappd_user is the untappd username',
                   ],
  'untappd_client_id' => '',
  'untappd_client_secret' => '',
  'untappd_user' => '',
  'untappd_tags' => '#social #untappd' # A good idea to provide this with an appropriate default setting
}

# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'UntappdLogger', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class UntappdLogger < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('untappd_user') || config['untappd_user'] == '' || config['untappd_client_id'] == '' || config['untappd_client_secret'] == ''
        @log.warn("<Untappd> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
      end
    else
      @log.warn("<Untappd> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging <Untappd> posts for #{config['untappd_user']}")

    tags = config['untappd_tags'] || ''
    tags = "\n\n#{tags}\n" unless tags == ''

    entries = Hash.new();
    Untappd.configure do |uconfig|
        uconfig.client_id = config['untappd_client_id']
        uconfig.client_secret = config['untappd_client_secret']
        uconfig.gmt_offset = Time.new.utc_offset / 3600
    end

    keep_going = true
    options = {} 
    next_id = 0
    while keep_going do
        extra = next_id > 0 ? "starting at #{next_id}..." : '...'

        @log.info "Requesting another set of checkins#{extra}"
        feed = Untappd::User.feed(config['untappd_user'], options)

        feed.checkins.items.each do |checkin|
            checkin_time = Time::strptime(checkin.created_at, '%a, %d %b %Y %H:%M:%S %z').localtime
            entry_key = checkin_time.strftime('%Y-%m-%d')
            next_id = checkin.checkin_id - 1

            if ! entries.has_key?(entry_key)
                entries[entry_key] = { 'checkins' => Array.new() }
            end

            if checkin_time >= timespan
                @log.info "[" + entry_key + "] Adding checkin " + checkin.created_at + ' ' + checkin.beer.beer_name
                entries[entry_key]['checkins'].push(checkin)
            else
                # We're done!
                @log.info "All done! (#{checkin_time}, #{timespan})"
                keep_going = false
                break
            end
        end

        if keep_going 
            # We need to request more items, so start where we left off
            options['max_id'] = next_id
        end
    end

    entries.keys.sort.each do |tstamp|
        if entries[tstamp]['checkins'].empty?
            # No checkin entries -- don't create journal entries
            next
        end        

        # The image in the entry will be that of the highest rated beer (with an image) 
        # that was checked in this day
        #
        image_url = ''
        image_rating = -1
        contenttext = "## Untappd Checkins\n"

        entries[tstamp]['checkins'].reverse.each do |checkin|
            rating_string = ''
            [1, 2, 3, 4, 5].each do |star|
                if star <= checkin.rating_score
                    rating_string += "\u2605" # black-star
                end
            end

            if checkin.rating_score % 1 != 0
                rating_string += "\u00BD" # 1/2
            end

            checkintext = "### [" + checkin.brewery.brewery_name + ' - ' + checkin.beer.beer_name + "](http://untappd.com/user/" + checkin.user.user_name + "/checkin/" + checkin.checkin_id.to_s + ")\n"
            checkintext += 'Rating: ' + rating_string + "\n"
            checkintext += checkin.checkin_comment
            checkintext += "\n\n"
            contenttext += checkintext

            # Choose the last beer consumed with an image that has the highest rating
            if checkin.rating_score >= image_rating && checkin.media.items.count > 0
                if checkin.media.items[0].photo.photo_img_og != ''
                    image_url = checkin.media.items[0].photo.photo_img_og
                    image_rating = checkin.rating_score
                end
            end
        end

        # create an options array to pass to 'to_dayone'
        # all options have default fallbacks, so you only need to create the options you want to specify
        options = {}
        options['content'] = "#{contenttext}#{tags}"

        # Create this to be the last entry of the day
        options['datestamp'] = Time::strptime(tstamp + ' 23:59:59', '%Y-%m-%d %H:%M:%S').utc.iso8601
        options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

        # Create a journal entry
        # to_dayone accepts all of the above options as a hash
        # generates an entry base on the datestamp key or defaults to "now"
        sl = DayOne.new
        if image_url == '' || sl.save_image(image_url, options['uuid'])
            sl.to_dayone(options)
        end
    end
  end
end

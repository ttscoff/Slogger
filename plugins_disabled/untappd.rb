=begin
Plugin: Untappd
Description: Query activity from untappd.com
Author: [Jon Nall](http://github.com/nall)
Configuration:
  untappd_user: ""
  untappd_access_token: ""
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
  'untappd_prefer_badge_image' => false,
  'untappd_tags' => '#social #untappd', # A good idea to provide this with an appropriate default setting
  'untappd_tags_checkin' => '#checkin',
  'untappd_tags_badge' => '#badge',
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

    Untappd.configure do |uconfig|
        uconfig.client_id = config['untappd_client_id']
        uconfig.client_secret = config['untappd_client_secret']
        uconfig.gmt_offset = Time.new.utc_offset / 3600
    end

    entries = Hash.new()
    entries = get_badges(entries)
    entries = get_checkins(entries)

    entries.keys.sort.each do |tstamp|
        ['checkins', 'badges' ].each do |key|
            if entries[tstamp][key] == nil
                entries[tstamp][key] = []
            end
        end

        # Choose an image! 
        #
        # Did we get badges? 
        #   Choose the one with the least levels. If there's a tie, use most recent
        #
        # Did we drink beer with images?
        #   Were there any unique beers? If so, use those
        #   Otherwise use the highest rated beer
        #
        # In all cases if there's a tie, use the most recent checkin
        #
        badge_image_url = ''
        checkin_image_url = ''

        has_badge_content = false
        has_checkin_content = false

        contenttext = "## Untappd Activity\n"
        if ! entries[tstamp]['badges'].empty?
            contenttext += "### Untappd Badges\n"
            best_badge = nil
            entries[tstamp]['badges'].reverse.each do |badge|
                has_badge_content = true

                contenttext += "#### #{badge.badge_name}\n#{badge.badge_description}\n"

                if best_badge == nil
                    best_badge = badge
                end

                if badge.levels.empty?
                    badge.levels = Hash.new()
                    badge.levels['count'] = 0
                end

                if badge.levels['count'] < best_badge.levels['count']
                    best_badge = badge
                    @log.info "Best badge today is #{badge.badge_name}"
                end

            end
            badge_image_url = best_badge['media']['badge_image_lg']
            contenttext += "\n"
        end

        if ! entries[tstamp]['checkins'].empty?
            image_rating = -1
            contenttext += "### Untappd Checkins\n"
            entries[tstamp]['checkins'].reverse.each do |checkin|
                has_checkin_content = true
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
                        checkin_image_url = checkin.media.items[0].photo.photo_img_og
                        image_rating = checkin.rating_score
                    end
                end
            end
        end

    
        tags = config['untappd_tags'] || ''

        if has_badge_content
            tags += " #{config['untappd_tags_badge']}" || ''
        end

        if has_checkin_content
            tags += " #{config['untappd_tags_checkin']}" || ''
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
        if has_badge_content || has_checkin_content
            sl = DayOne.new

            image_url = ''
            if config['untappd_prefer_badge_image']
                image_url = badge_image_url
                if image_url == ''
                    image_url = checkin_image_url
                end
            else
                image_url = checkin_image_url
                if image_url == ''
                    image_url = badge_image_url
                end
            end

            if image_url == '' || sl.save_image(image_url, options['uuid'])
                sl.to_dayone(options)
            end
        end
    end
  end

    def get_checkins(results)
        keep_going = true
        options = {} 
        next_id = 0
        config = @config[self.class.name]
        while keep_going do
            extra = next_id > 0 ? "starting at #{next_id}..." : '...'

            @log.info "Requesting another set of checkins#{extra}"
            feed = Untappd::User.feed(config['untappd_user'], options)

            if feed.checkins.items.empty?
                @log.info "No more checkins to process!"
                break
            end

            feed.checkins.items.each do |checkin|
                checkin_time = Time::strptime(checkin.created_at, '%a, %d %b %Y %H:%M:%S %z').localtime
                entry_key = checkin_time.strftime('%Y-%m-%d')
                next_id = checkin.checkin_id - 1

                if ! results.has_key?(entry_key)
                    results[entry_key] = Hash.new()
                end
                if ! results[entry_key].has_key?('checkins')
                    results[entry_key]['checkins'] = Array.new()
                end

                if checkin_time >= timespan
                        @log.info "[" + entry_key + "] Adding checkin " + checkin.created_at + ' ' + checkin.beer.beer_name
                        results[entry_key]['checkins'].push(checkin)
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

        return results
    end

    def get_badges(results)
        keep_going = true
        options = {} 
        offset = 0
        config = @config[self.class.name]
        while keep_going do
            extra = offset > 0 ? "starting at #{offset}..." : '...'

            @log.info "Requesting another set of badges#{extra}"
            badges = Untappd::User.badges(config['untappd_user'], options)

            if badges.items.empty?
                @log.info "No more badges to process!"
                break
            end

            badges.items.each do |badge|
                badge_time = Time::strptime(badge.created_at, '%a, %d %b %Y %H:%M:%S %z').localtime
                entry_key = badge_time.strftime('%Y-%m-%d')
                offset += 1

                if ! results.has_key?(entry_key)
                    results[entry_key] = Hash.new()
                end
                if ! results[entry_key].has_key?('badges')
                    results[entry_key]['badges'] = Array.new()
                end

                if badge_time >= timespan
                        @log.info "[" + entry_key + "] Adding badge " + badge.created_at + ' ' + badge.badge_name
                        results[entry_key]['badges'].push(badge)
                else
                    # We're done!
                    @log.info "All done! (#{badge_time}, #{timespan})"
                    keep_going = false
                    break
                end
            end

            if keep_going 
                # We need to request more items, so start where we left off
                options['offset'] = offset
            end
        end
        
        return results
    end
end

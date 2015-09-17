=begin
Plugin: GoogleAnalyticsLogger
Description: Daily Web Site Stats Logger
Author: [Hilton Lipschitz](http://www.hiltmon.com)
Configuration:
  client_id: 'XXXXXXXXXXXXXX.apps.googleusercontent.com'
  client_secret: 'XXXXXXXXXXXXXXXX'
  auth_code: '4/XXXXXXXXXXXXXXXXXXXXXXXXXXX'
  properties: [ 'UA-XXXXXXXX-1', 'UA-XXXXXXX-2' ]
  show_sources: true
  shouw_popular_pages: true
Notes:
  PREREQUISITES:
  - You must patch `slogger.rb` and put this file in `plugins`
  - The patch is at line slogger.rb:173, replace `eval(plugin['class']).new.do_log` with:
    if plugin['updates_config'] == true
      # Pass a reference to config for mutation
      eval(plugin['class']).new.do_log(@config)
    else
      # Usual thing (so that we don't break other plugins)
      eval(plugin['class']).new.do_log
    end
  SETUP:
  - The setup process is a pain the neck. You need to create an Installed Application API access at Google (or use mine, but it may die at any time while in Alpha). Then:
     - Run `./slogger` to create or update the config file.
     - In slogger_config, paste in the Client ID and Secret, then save and close it.
     - Run `./slogger -o Google` again to use these ID's to acquire an auth code, it will launch your default browser to do this.
     - Paste the auth_code into your slogger_config, save and close again.
     - Once that is done, this script should pick up a 2-week access token on the next run and refresh that automatically using its refresh token.
     - TROUBLESHOOTING: If you start to get authentication errors, delete the auth_token, access_token and refresh_token and try again. Make sure that the slogger_config file is saved and closed before you run `./slogger -o Google` again.

  YESTERDAY:
  - Since Google Analytics is date (not time) based, we cannot follow the usual Slogger process of including all the data that fits between the given timestamps (since the last run). Instead, if the given start time is yesterday or before, it requests the data by date, compacts the data to a daily record then appends each daily to a daily content body. Once the bodies are all created, it creates a DayOne entry for each date (for each site).
  - If the last run date is today, this logger intentionally does nothing.

  BACK FILL:
  - Feel free to use the Slogger -t DAYS parameter to back-fill your journal, but do this only once, this Logger does not check to see if an entry already appears for a date.
=end

config = { # description and a primary key (username, url, etc.) required
  'description' => [
    'Logs up to yesterday\'s Web Stats.',
    'client_id is the Client ID for installed applications from the Google API site',
    'client_secret is the Client Secret for this ID',
    'auth_code is the code you pasted from the initial OAuth2 web session',
    'access_token is the saved 2-week token (DO NOT manually set)',
    'refresh_token is the saved token to refresh the 2-week token (DO NOT manually set)',
    'properties is an array of google property codes (UA-XXXXXXX-X) to log, needs at least one',
    'show_sources (true/false) determines whether to list the top 5 sources of traffic',
    'show_popular_pages (true/false) determines whether to list the top 10 most popular pages'
  ],
  'client_id' => '',
  'client_secret' => '',
  'auth_code' => '',
  'access_token' => '',
  'refresh_token' => '',
  'properties' => [],
  'show_sources' => true,
  'show_popular_pages' => true,
  'tags' => '#social #sitestats'
}

# ALERT: This registration assumes `slogger.rb` has been updated
$slog.register_plugin({ 'class' => 'GoogleAnalyticsLogger', 'config' => config, 'updates_config' => true })

require 'rubygems' # IF using system Ruby 1.8.7
require 'google/api_client'

class GoogleAnalyticsLogger < Slogger

  # ALERT: Has a parameter, you did remember to update `slogger.rb` right?
  def do_log

    # Check Setup
    if @config.key?(self.class.name)
      config = @config[self.class.name]

      # Check Phase 1: Did the user set up an app for API access and go through the process?
      if !config.key?('client_id') || config['client_id'] == ""
        @log.warn("Google Analytics has not been configured, please create an installed application at google.")
        return
      end
    else
      @log.warn("Google Analytics has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end

    @log.info("Logging Google Analytics posts")

    show_sources = config['show_sources'] || true
    show_popular_pages = config['show_popular_pages'] || true

    # Google data is by date, not time, start is the given date,
    # End date must be yesterday or we'll lose stats for today
    # @log.info("Last run date #{@timespan.iso8601.to_s.split('T')[0]}")
    start_date = "#{@timespan.iso8601.to_s.split('T')[0]}"
    end_date   = "#{Date.today - 1}" # Always yesterday

    if Date.parse(start_date) > Date.parse(end_date)
      @log.warn("Start_date is after end_date, nothing to do.")
      return
    end

    @log.info("Run for #{start_date} - #{end_date}")

    slogger_version = MAJOR_VERSION.to_s + '.' + MINOR_VERSION.to_s + '.' + BUILD_NUMBER.to_s

    # Here we go
    client = Google::APIClient.new(
      :application_name => 'Slogger',
      :application_version => slogger_version,
    )

    # Initialize OAuth 2.0 client
    client.authorization.client_id = config['client_id']
    client.authorization.client_secret = config['client_secret']
    client.authorization.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob' # Redirect URIs so we can see the auth token
    client.authorization.scope = 'https://www.googleapis.com/auth/analytics.readonly'
    redirect_uri = client.authorization.authorization_uri

    # GUI Auth if no auth_code present
    # Note, the auth_code is single use, you need to nuke and get a new one if anything else fails
    if !config.key?('auth_code') || config['auth_code'] == ""
      @log.warn("You need to authorize the Google Analytics logger. Copy the code at the end to the auth_code field in your slogger_config file")
      url = URI.parse(redirect_uri)
      # @log.info("Launching #{url}")
      %x{open "#{url}"}
      return
    end

    # Convert to an access token if we can (first run after getting auth_code also gives us a refresh_token)
    # If you do not get a refresh token, it means that the client IS is NOT for installed applications
    if !config.key?('access_token') || config['access_token'] == ""
      @log.info("Getting access Token...")
      client.authorization.code = config['auth_code']
      new_tokens = client.authorization.fetch_access_token!

      config['access_token'] = new_tokens['access_token']
      config['refresh_token'] = new_tokens['refresh_token']
      #
      # mutable_config['GoogleAnalyticsLogger']['access_token'] = new_tokens['access_token']
      # mutable_config['GoogleAnalyticsLogger']['refresh_token'] = new_tokens['refresh_token']
    end

    client.authorization.access_token = config['access_token']
    client.authorization.refresh_token = config['refresh_token']

    # TODO: Wait two weeks for the current access_token to expire, then see if this
    # works. It's supposed to according to Google, but no way to test it. Sigh.
    if client.authorization.refresh_token && client.authorization.expired?
      @log.info("Refreshing access Token...")
      new_tokens = client.authorization.fetch_access_token!
      config['access_token'] = new_tokens['access_token']
      # mutable_config[self.class.name]['access_token'] = new_tokens['access_token']
    end

    # If we get here, its likely we have defeated the OAuth2 boss level

    # Discover the API
    analytics = client.discovered_api('analytics', 'v3')

    # Build a list of GA profiles available
    result = client.execute(
      :api_method => analytics.management.profiles.list,
      :parameters => {'accountId' => '~all', 'webPropertyId' => '~all'}
    )
    profiles = {}
    if result.data['error'] != nil
      @log.warn("Google Analytics profile error: #{result.data.inspect}")
      return config
    end

    # If we get here, we've saved the princess and this Logger is working fine

    # Cache the profiles
    result.data.items.each do |item|
      profiles[item.webPropertyId] = [ item.id, item.name.gsub('/', '') ] # Trimming useless '/' at end?
    end

    # For each web site requested by the user
    config['properties'].each do |property|

      if profiles[property].nil?
        @log.warn("Unmatched Google Analytics Profile #{property}")
        next
      end

      key = profiles[property][0]
      site = profiles[property][1]
      ga_key = "ga:#{key}"

      @log.info("- Getting Site Stats for #{site}...")

      content = {} # Hash of date bodies

      # Get total page views
      result = client.execute(
        :api_method => analytics.data.ga.get,
        :parameters => {
          'ids' => ga_key,
          'dimensions' => 'ga:date',
          'metrics' => 'ga:pageviews',
          'start-date' => start_date,
          'end-date' => end_date
        }
      )

      result.data.rows.each do |row|
        content[row[0]] = [ "## Site Stats for #{site}" ]
        content[row[0]] << "Page Views: **#{row[1]}**"
      end

      # Break down your visitors into new and returning
      result = client.execute(
        :api_method => analytics.data.ga.get,
        :parameters => {
          'ids' => ga_key,
          'dimensions' => 'ga:date,ga:visitorType',
          'metrics' => 'ga:visits',
          'start-date' => start_date,
          'end-date' => end_date
        }
      )

      compact_data = {}
      result.data.rows.each do |row|
        if compact_data[row[0]] == nil
          compact_data[row[0]] = [ row[2] ] # New Visits
        else
          compact_data[row[0]] << row[2] # Returning
        end
      end

      compact_data.each do |key, row|
        content[key] << "Visitors  : **#{row[0].to_i + row[1].to_i}** (New: #{row[0]}, Returning: #{row[1]})"
      end

      # Show the top 5 sources of page views (if requested)
      if show_sources == true
        result = client.execute(
          :api_method => analytics.data.ga.get,
          :parameters => {
            'ids' => ga_key,
            'dimensions' => 'ga:date,ga:source,ga:medium',
            'metrics' => 'ga:visits,ga:pageviews',
            'sort' => 'ga:date,ga:visits',
            'start-date' => start_date,
            'end-date' => end_date
          }
        )

        compact_data = {}
        result.data.rows.reverse.each do |row|
          line = "* **#{row[1]}**: (#{row[2]}: #{row[3]} Visits, #{row[4]} Pageviews)"
          if compact_data[row[0]] == nil
            compact_data[row[0]] = [ line ] # Top Ranking for the date
          else
            compact_data[row[0]] << line unless compact_data[row[0]].length >= 5
          end
        end

        compact_data.each do |key, row|
          content[key] << "### Top 5 Sources"
          content[key] = content[key].concat(row)
        end
      end

      # Show the top 10 most popular pages for a given date with links
      # NOTE: GA logs www.xxx.com and xxx.com separately, too bad, so sad, your dad.
      if show_popular_pages == true
        result = client.execute(
          :api_method => analytics.data.ga.get,
          :parameters => {
            'ids' => ga_key,
            'dimensions' => 'ga:date,ga:pageTitle,ga:hostName,ga:pagePath',
            'metrics' => 'ga:pageviews,ga:uniquePageviews,ga:timeOnPage',
            'sort' => 'ga:date,ga:pageviews',
            'start-date' => start_date,
            'end-date' => end_date
          }
        )

        compact_data = {}
        result.data.rows.reverse.each do |row|
          line = "* [#{row[1]}](http://#{row[2]}#{row[3]}): #{row[4]} Views, #{row[5]} Uniques, #{'%.2f' % (row[6].to_f/row[4].to_f)}s Avg Time on Page"
          if compact_data[row[0]] == nil
            compact_data[row[0]] = [ line ] # Top Ranking for the date
          else
            compact_data[row[0]] << line unless compact_data[row[0]].length >= 10
          end
        end

        compact_data.each do |key, row|
          content[key] << "### Top 10 Viewed Pages"
          content[key] = content[key].concat(row)
        end
      end

      # And create a Journal entry for each date body
      tags = config['tags'] || ''
      content.each do |key, body|
        logdate = "#{key[0..3]}-#{key[4..5]}-#{key[6..7]}"
        body << "(#{tags})" unless tags == ''

        # And Log to Day One
        options = {}
        options['content'] = body.join("\n\n")
        options['datestamp'] = Time.parse(logdate + " 23:59:00").utc.iso8601

        sl = DayOne.new
        sl.to_dayone(options)
      end
    end
    return config
  end
end

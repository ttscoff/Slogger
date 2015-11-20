=begin
Plugin: MovesApp Logger
Description: Proof of Concept Exporter for Moves.app (one line)
Author: Martin R.J. Cleaver (http://github.com/mrjcleaver)
Configuration:
  option_1_name: [ "example_value1" , "example_value2", ... ]
  option_2_name: example_value
Notes:
- This connects to Moves, and dumps the JSON.


- It is not pretty. It's a starting point.
- you need to generate an Access Token, Client ID and Client Secret
- the functionality for this generation is not yet part of this logger
- instead you can get these init tokens via https://github.com/pwaldhauer/elizabeth, the NodeJS MovesApp project
- after which you can switch to using the MovesApp Logger

Ready your slogger_config file with the MovesAppLogger section
- ruby slogger --update-config

Getting Your Tokens using Elizabeth's init
- to generate these you need to
./ellie.js init
more ~/.elizabeth.json
{
  "moves": {
    "clientId": "...",
    "clientSecret": "....",
    "redirectUri": "http://localhost:3000/auth",
    "accessToken": "..."
- now let MovesAppLogger use this by copying those values into your Slogger_config file

Now you can use the MovesAppLogger
-- slogger --onlyrun movesapplogger

Improving the MovesAppLogger
- Yup, JSON is ugly an not useful
- Images would be nice
- Your contribution goes here etc.

=end

# To your Gemfile, you'll want to add:
# gem 'moves' # for movesapp
# and then bundle install
require 'moves'; # https://github.com/ankane/moves.git

config = { # description and a primary key (username, url, etc.) required
  'description' => ['Moves logger'],
  'service_username' => '', # update the name and make this a string or an array if you want to handle multiple accounts.
  'additional_config_option' => false,
  'clientId' => '',
  'clientSecret' => '',
  'redirectUri' => 'http://localhost:3000/auth',
  'accessToken' => '',
  'tags' => '#movesapp' # A good idea to provide this with an appropriate default setting
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'MovesAppLogger', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class MovesAppLogger < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('service_username') || config['service_username'] == []
        @log.warn("MovesAppLogger has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        username = config['service_username']
      end
    else
      @log.warn("MovesAppLogger has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.level = Logger::DEBUG

    if config['debug'] then         ## TODO - move into the Slogger class.
      @log.level = Logger::DEBUG
      @log.debug 'Enabled debug mode'
    end

    @log.info("Logging MovesAppLogger posts from MovesApp API")
    @log.info config

    tags = config['tags'] || ''
    @_tags = "\n\n#{tags}\n" unless tags == ''



    @log.debug "Timespan formatted:"+@timespan.strftime("%l %M")
    last_run = config['MovesAppLogger_last_run']
    @current_run_time = Time.now

    def no_mins(t) # http://stackoverflow.com/a/4856312/722034
      Time.at(t.to_i - t.sec - t.min % 60 * 60)
    end

    if (@to.nil?)
      time_to = no_mins(@current_run_time)
    else
      time_to = Time.parse(@to)
    end

    if (@from.nil?)
      time_from = no_mins(Time.parse(last_run))
    else
      time_from = Time.parse(@from)
    end

    if (@to and (@from == @to))
      time_to = time_from + (3600 * 24 - 1)
      @log.debug("As from==to, assuming we mean the 24 hours starting at "+@from)
    end

    @log.debug "From #{time_from} to #{time_to}"
    exporter = MovesAppExporter.new(config, @log)

    add_blog_for_period(time_from, time_to, exporter)


  end

  def add_blog_for_period(from, to, exporter)
    title = "MovesApp (Auto; #{from.strftime("%l %p")}-#{to.strftime("%l %p")}; exported at #{@current_run_time.strftime("%FT%R")})"

    # Perform necessary functions to retrieve posts
    #
    content = exporter.getContent(from, from, to)         # current_hour, or since last ran

    if content.nil? or content == ''
      @log.debug("No content = no blog post")
      return
    end

    one_minute_before_hour = to - 60 # Put it in at e.g. 9:59 am, so it's in the right hour
    blog_date_stamp = one_minute_before_hour.utc.iso8601

    @log.debug "Writing to datestamp "+blog_date_stamp
    # create an options array to pass to 'to_dayone'
    # all options have default fallbacks, so you only need to create the options you want to specify
    options = {}
    options['content'] = "## #{title}\n\n#{content}\n#{@_tags}"
    options['datestamp'] = blog_date_stamp
    options['starred'] = false
    options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

    # Create a journal entry
    # to_dayone accepts all of the above options as a hash
    # generates an entry base on the datestamp key or defaults to "now"
    sl = DayOne.new
    pp sl.to_dayone(options)


    # To create an image entry, use `sl.to_dayone(options) if sl.save_image(imageurl,options['uuid'])`
    # save_image takes an image path and a uuid that must be identical the one passed to to_dayone
    # save_image returns false if there's an error
  end

end


class MovesAppExporter
  require 'moves'

  def initialize(config, log)
    @config = config
    @log = log
    @access_token = config['accessToken']
    if @access_token.nil?
      log.error "Access Token is Not Set!"
      exit 1
    end
    @log.debug "Logging into Moves.app with #{@access_token}"
    @moves = Moves::Client.new(@access_token)
  end



  def getContent(date_from, from, to)

    @tzformat = "%Y-%m-%d"

    ## TODO
    # check # max 31 days period, or other Moves API constraint.

    from_formatted = from.strftime(@tzformat)
    to_formatted = to.strftime(@tzformat)

    #puts Time.now.utc.iso8601
    @log.info("FROM=#{from_formatted} TO=#{to_formatted}")

    @log.debug "call"

    result = @moves.daily_activities(:from => from_formatted, :to => to_formatted)
    #result = result +"\n"+ @moves.daily_summary(:from => from_formatted, :to => to_formatted)
    #result = result + "\n" + @moves.daily_places(:from => from_formatted, :to => to_formatted)
    #result = result + "\n" + @moves.daily_storyline(:from => from_formatted, :to => to_formatted)
    # .activity_list
    # track_points => true
    @log.debug result
    return result
  end

end


#MovesAppExporter.new()

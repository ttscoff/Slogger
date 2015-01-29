=begin
Plugin: TimingApp Logger
Description: Exporter from Timing.app (one line)
Author: Martin R.J. Cleaver (http://github.com/mrjcleaver)
Configuration:
  option_1_name: [ "example_value1" , "example_value2", ... ]
  option_2_name: example_value
Notes:
  - multi-line notes with additional description and information (optional)
=end

config = { # description and a primary key (username, url, etc.) required
  'description' => ['Main description',
                    'additional notes. These will appear in the config file and should contain descriptions of configuration options',
                    'line 2, continue array as needed'],
  'service_username' => '', # update the name and make this a string or an array if you want to handle multiple accounts.
  'additional_config_option' => false,
  'tags' => '#social #timetracking' # A good idea to provide this with an appropriate default setting
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'TimingAppLogger', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class TimingAppLogger < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('service_username') || config['service_username'] == []
        @log.warn("TimingAppLogger has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        username = config['service_username']
      end
    else
      @log.warn("TimingAppLogger has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end

    pp config
    if config['debug'] then         ## TODO - move into the Slogger class.
      @log.level = Logger::DEBUG
      @log.debug 'Enabled debug mode'
    end

    @log.info("Logging TimingAppLogger posts from TimingApp API")

    tags = config['tags'] || ''
    @_tags = "\n\n#{@tags}\n" unless @tags == ''



    @log.debug "" + @timespan.strftime("%l %M")
    last_run = config['TimingAppLogger_last_run']

    def no_mins(t) # http://stackoverflow.com/a/4856312/722034
      Time.at(t.to_i - t.sec - t.min % 60 * 60)
    end

    time_now = no_mins(Time.now)
    time_last_run = no_mins(Time.parse(last_run))

    hours = (time_now - time_last_run) / 3600
    exporter = TimingAppExporter.new(@config, @log)

    hour = time_last_run
    while hour < time_now
      @log.debug "Doing "+hour.to_s
      add_blog_for_period(hour, hour+3600, exporter)

      hour += 3600
    end

  end

  def add_blog_for_period(from, to, exporter)
    @tzformat = "%F,%l:00 %p"

    from_formatted = from.strftime(@tzformat)
    to_formatted = to.strftime(@tzformat)

    title = "TimingApp records (from=#{from_formatted} to datestamp=#{to_formatted})"


    # Perform necessary functions to retrieve posts

    content = exporter.getContent(from_formatted, to_formatted)         # current_hour, or since last ran

    if content.nil?
      @debug.log("No content = no blog post")
      return
    end

    one_minute_before_hour = to - 60 # Put it in at e.g. 9:59 am, so it's in the right hour
    blog_date_stamp = one_minute_before_hour.utc.iso8601

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
    sl.to_dayone(options)

    # To create an image entry, use `sl.to_dayone(options) if sl.save_image(imageurl,options['uuid'])`
    # save_image takes an image path and a uuid that must be identical the one passed to to_dayone
    # save_image returns false if there's an error
  end

end


class TimingAppExporter

  require 'chronic_duration'

  def initialize(config, log)
    @config = config
    @log = log

  end

  def postProcess(record, fields, sep)
    @log.debug(record)
    @log.debug("Fields in: "+fields.join(','))

    newLine = ""
    n = 0
    min_sec = 1.5 * 60
    rounded_secs = 3 * 60
    fields.each do |fieldName|
#      @log.debug fieldName
      value = record[fieldName]

      if fieldName == 'duration'
        secs = ChronicDuration.parse(value)
        secs = ((secs + min_sec) / (rounded_secs)).round * rounded_secs
        value = ChronicDuration.output(secs)
      end

      if value.kind_of?(Array)
        newLine = newLine + value.join(',') + sep
      else
        newLine = newLine + value + sep
      end
    end
    newLine = newLine +"\n"
    @log.debug(newLine)
    @log.debug("")
    return newLine
  end

  def filterContent(input_file, output_file, filter)
    filter = filter.gsub("\n", '')

    @log.debug "FILTER: #{filter}"

    # https://github.com/trentm/json
    cmd = %Q(cat "#{input_file}" | json -c '#{filter}'   > #{output_file})
    @log.debug cmd
    `#{cmd}`

    if @debug
      puts "BEFORE"
      `cat #{input_file}`

      puts "AFTER"
      `cat #{output_file}`
    end
  end

  def getContent(from, to)
    #from = top_of_hour(from)
    #to = top_of_hour(to)

    #puts Time.now.utc.iso8601
    @log.info("FROM=#{from} TO=#{to}")
    tmp_file = "/tmp/timing_output"
    filtered_output = "/tmp/processed_output"
    my_script(tmp_file)


    filter = %Q(this.startDate >= "#{from}" &&
                this.startDate < "#{to}"               )

    filterContent(tmp_file, filtered_output, filter)



    duration_minimum = '0:03:00'
#   this.duration > "#{duration_minimum}"




    # Post-process
    file = open(filtered_output)
    json = file.read

    parsed = JSON.parse(json)

    fields = %w(duration application projects path startDate)
    headers = fields.join(" ")

    sep = "|"
    ans = ''
    parsed.each   do |record|
       @log.info record['startDate']

       # TODO: generalize this
       if record['path'].to_s.start_with?('/Volumes')
         record['path'] = "file:/"+record['path']
       end
       line = postProcess(record, fields, sep)
       ans = ans + line
    end

    if !ans.empty?
      headerFormatted = fields.join(" | ")+" \n"
      headerFormatted = headerFormatted + "--- | " * fields.length + "\n"
      return headerFormatted + ans
    else
      return nil
    end

  end

  def osascript(script)
    system 'osascript', *script.split(/\n/).map { |line| ['-e', line] }.flatten
  end

  def my_script(temp_file)
    if (File.exists?(temp_file)) then
      File.delete(temp_file)
    end

    script =<<"APPLESCRIPT"
      tell application "Timing"
        set ex to make new export
        set first day of ex to ((current date) - 1 * days)
        set last day of ex to current date
        set export mode of ex to raw

        set duration format of ex to hhmmss
        set pretty print json of ex to false
        set should exclude short entries of ex to true
        save export ex to "#{temp_file}"
      end tell
APPLESCRIPT

    osascript(script)

    if (! File.exists?(temp_file)) then
      temp_script = '/tmp/s'
      @log.error(temp_file + " with output from TimingApp was not made")
      # if you see compile errors from AppleScript, write it to a temp file and execute with osascript
      # to get the line number

      File.open(temp_script, 'w') {|f| f.write(script) }
      @log.error('run osascript '+temp_script)
      exit 1
    end



  end
end


#TimingAppExporter.new()

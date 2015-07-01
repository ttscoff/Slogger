=begin
Plugin: TimingApp Logger
Description: Exporter from Timing.app (one line)
Author: Martin R.J. Cleaver (http://github.com/mrjcleaver)
Configuration:
  option_1_name: [ "example_value1" , "example_value2", ... ]
  option_2_name: example_value
Notes:
  - You need alasql (a javascript SQL library): npm install -g alasql

=end

config = { # description and a primary key (username, url, etc.) required
  'description' => ['Main description',
                    'additional notes. These will appear in the config file and should contain descriptions of configuration options',
                    'line 2, continue array as needed'],
  'service_username' => '', # update the name and make this a string or an array if you want to handle multiple accounts.
  'additional_config_option' => false,
  'tags' => '#timingapp' # A good idea to provide this with an appropriate default setting
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
    @log.level = Logger::DEBUG

    if config['debug'] then         ## TODO - move into the Slogger class.
      @log.level = Logger::DEBUG
      @log.debug 'Enabled debug mode'
    end

    @log.info("Logging TimingAppLogger posts from TimingApp API")

    tags = config['tags'] || ''
    @_tags = "\n\n#{@tags}\n" unless @tags == ''



    @log.debug "Timespan formatted:"+@timespan.strftime("%l %M")
    last_run = config['TimingAppLogger_last_run']
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

    hours = (time_to - time_from) / 3600
    exporter = TimingAppExporter.new(@config, @log)
    period = 3600 # 1 hour

    from = time_from
    while from < time_to
      @log.debug("")

      @log.debug "Doing "+from.to_s
      add_blog_for_period(from, from+period, exporter)

      from += period
    end

  end

  def add_blog_for_period(from, to, exporter)
    @tzformat = "%F, %-l:00 %p"

    from_formatted = from.strftime(@tzformat)
    to_formatted = to.strftime(@tzformat)

    title = "TimingApp (Auto; #{from.strftime("%l %p")}-#{to.strftime("%l %p")}; exported at #{@current_run_time.strftime("%FT%R")})"


    # Perform necessary functions to retrieve posts

    content = exporter.getContent(from, from_formatted, to_formatted)         # current_hour, or since last ran

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
    #puts "NOT ACTUALLY DOING THE ENTRY"
    #exit 1

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
    #@log.debug "Record:"
    #@log.debug   record
    #@log.debug("Fields in: "+fields.join(','))

    newLine = sep
    n = 0
    min_sec = 1.5 * 60
    rounded_secs = 3 * 60
    valid = false
    fields.each do |fieldName|
#      @log.debug fieldName
      value = record[fieldName]
      if (!value.nil?)
        valid = true
      end

      if fieldName == 'duration'
        secs = ChronicDuration.parse(value)
        secs = ((secs + min_sec) / (rounded_secs)).round * rounded_secs
        value = ChronicDuration.output(secs)
      end

      if value.kind_of?(Array)
        newLine = newLine + value.join(',') + sep
      else
        newLine = newLine + value.to_s + sep
      end
    end
    newLine = newLine +"\n"

    if valid
      @log.debug("line:"+newLine)
      return newLine
    else
      @log.debug "Skipped empty line"
      return ""
    end

  end

  def filterContent(external_program, input_file, output_file, filter)

    cmd = %Q(cat "#{input_file}" | #{external_program} '#{filter}'   > #{output_file})
    @log.debug cmd
    `#{cmd}`

    if @debug
      puts "BEFORE"
      `cat #{input_file}`

      puts "AFTER"
      `cat #{output_file}`
    end
  end

  def alasql_setup
    script=<<"JAVASCRIPT"
//var alasql = require('/usr/local/lib/node_modules/alasql/alasql.min.js');
if(typeof exports === 'object') {
        var assert = require("assert");
        var alasql = require('/usr/local/lib/node_modules/alasql/alasql.min.js');   // technically a straight require("alasql") should work
} else {
        __dirname = '.';
};

alasql.fn.myDuration = function(secs) {
    return Math.floor(secs/60);
}

function stringify_alasql(query) {
	alasql(query,[],function(res){
                  console.log(JSON.stringify(res));
	})
}
JAVASCRIPT
    return script
  end




  def make_filter_for_alasql(script, var)


    script = script +"\n"+'stringify_alasql('+var+')'

    filter_script = '/tmp/alasql.js'
    File.open(filter_script, 'w') {|f| f.write(alasql_setup+script) }

    #@log.debug "Filter script: "+filter_script

    return filter_script
  end

  def json_as_csv(json_file, fields)
    file = open(json_file).read
    parsed = JSON.parse(file)
    sep = '|'
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

    @log.debug "As CSV=" + ans

    if !/\A\s*\z/.match(ans) # empty
      headerFormatted = fields.join(" "+sep+" ")+" \n"
      headerFormatted = sep+" "+headerFormatted + ("--- "+sep+" ") * fields.length + "\n"
      return headerFormatted + ans
    else
      return ''
    end
  end

  # Precondition: to and from are on the same date.
  # TODO: check this precondition.
  def getContent(date_from, from, to)
    #from = top_of_hour(from)
    #to = top_of_hour(to)

    #puts Time.now.utc.iso8601
    @log.info("FROM=#{from} TO=#{to}")
    raw_timing_output_file = "/tmp/timing_output"
    filtered_output_file = "/tmp/processed_output"

    date_for_applescript = date_from.strftime("%A, %B %-e, %Y at 00:00") # e.g.   "Monday, February 9, 2015"

    get_whole_day_from_timing(raw_timing_output_file, date_for_applescript)

    @log.debug("From #{raw_timing_output_file}, extracting hours from #{from} to #{to}: ")


    startDateBegin = date_from.strftime("%Y-%m-%d, %-l:%M %p")

    @log.debug("Doing outline")
    outline_script =<<-"ALASQL"
          var select = 'SELECT projects, path, application, myDuration([duration]) as minutes, myDuration(SUM([duration])) as totalMins \
            FROM json("") \
            WHERE startDate = "#{startDateBegin}" \
            GROUP BY projects, totalMins \
            ORDER BY totalMins DESC, projects DESC \
            ;'
    ALASQL

    filterContent("node",
                  raw_timing_output_file,
                  filtered_output_file,
                  make_filter_for_alasql(
                      outline_script, 'select')
    )

    outline = json_as_csv(filtered_output_file, %w(projects totalMins))


    @log.debug("Doing total")
    total_script =<<-"ALASQL"
          var total = 'SELECT myDuration(SUM([duration])) as totalMins \
            FROM json("") \
            WHERE startDate = "#{startDateBegin}" \
            ;'
    ALASQL

    filterContent("node",
                  raw_timing_output_file,
                  filtered_output_file,
                  make_filter_for_alasql(
                      total_script, 'total')
    )

    total = json_as_csv(filtered_output_file, %w(projects totalMins))

    @log.debug("Doing detail")
    detail_script =<<-"ALASQL"
          var detail = 'SELECT projects, path, application, myDuration([duration]) as minutes \
            FROM json("") \
            WHERE startDate = "#{startDateBegin}" \
            GROUP BY projects, minutes, path, application, duration \
            ORDER BY projects DESC \
            ;'
    ALASQL

    filterContent('node',
                  raw_timing_output_file,
                  filtered_output_file,
                  make_filter_for_alasql(
                        detail_script, 'detail')
                 )

    detail = json_as_csv(filtered_output_file, %w(projects minutes application path startDate))

    if detail.length > 1
      if outline.length > 1
        @log.debug ">"+outline
        outline = "### Outline\n"+ outline +"\n" + total
      end
      detail = "### Detail\n" + detail
      return outline + detail
    end
    return nil
  end

  def osascript(script)
    system 'osascript', *script.split(/\n/).map { |line| ['-e', line] }.flatten
  end

  def get_whole_day_from_timing(temp_file, date)
    if (File.exists?(temp_file)) then
      File.delete(temp_file)
    end

    @log.debug "Timing: exporting the whole of "+date+ " to "+temp_file
    script =<<"APPLESCRIPT"
      set dateString to date "#{date}"
      tell application "Timing"
        set ex to make new export

        set first day of ex to dateString
        set project names of ex to "All Activities"
        set last day of ex to dateString
        set export mode of ex to raw

        set duration format of ex to seconds
        set pretty print json of ex to true
        set should exclude short entries of ex to true
        save export ex to "#{temp_file}"
      end tell
APPLESCRIPT
#        set duration format of ex to hhmmss
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

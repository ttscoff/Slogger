=begin
Plugin: Reporter logger
Description: Parses log files created by the reporter app for iPhone (http://www.reporter-app.com),
an app that asks you questions throughout the day. The logger will create a single entry for all entries of each day.
Notes: Inside the reporter app itself you will need to enable Save to Dropbox in the export settings.
This logger also doesn't try to parse all the data from the app, but instead focusing on the main information.
Author: [Arjen Schwarz](https://github.com/ArjenSchwarz)
Configuration:
  reporter_source_directory: "/path/to/dropbox/Apps/Reporter-App"
  reporter_all_entries: true/false (This will make it run on all reporter files in the source directory. Resets to false after use)
  reporter_star: true/false
  reporter_tags: "#reporter"
  reporter_use_fahrenheit: true/false (Default is false, which makes it use Celcius)
=end

config = {
  'description' => ['Parses log files created by the reporter app for iPhone'],
  'reporter_source_directory' => '',
  'reporter_all_entries' => false,
  'reporter_star' => false,
  'reporter_tags' => '',
  'reporter_use_fahrenheit' => false
}

$slog.register_plugin({ 'class' => 'ReporterLogger', 'config' => config })

class ReporterLogger < Slogger
	require 'date'
	require 'time'

	def do_log
    if @config.key?(self.class.name)
  	  config = @config[self.class.name]
    		if !config.key?('reporter_source_directory') || config['reporter_source_directory'] == ""
      		@log.warn("ReporterLogger has not been configured or an option is invalid, please edit your slogger_config file.")
      		return
    		end
  	else
    		@log.warn("ReporterLogger has not been configured, please edit your slogger_config file.")
    	return
    end
    developMode = $options['develop']
    @tags = config['reporter_tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    filelist = get_filelist(config)

    filelist.each do |inputFile|
      options = {}
      options['starred'] = config['reporter_star']

      f = File.new(File.expand_path(inputFile))
      content = JSON.parse(f.read)
      f.close

      nr_entries = content['snapshots'].count

      snapshots = Array.new()
      if nr_entries > 0
        content['snapshots'].each do |snapshot|
          snapshot_date = DateTime.parse(snapshot['date'])
          snapshot_text = sprintf("\n## %s\n", snapshot_date.strftime(@time_format))
          snapshot_text += get_location(snapshot['location'])
          snapshot_text += get_weather(snapshot['weather'], config['reporter_use_fahrenheit'])
          if snapshot.has_key? 'steps'
            snapshot_text += sprintf("* Steps taken: %s\n", snapshot['steps'])
          end
          if snapshot.has_key? 'photoSet'
            snapshot_text += sprintf("* Photos taken: %s\n", snapshot['photoSet']['photos'].count)
          end
          snapshot_text += get_responses(snapshot['responses'])
          snapshots.push(snapshot_text)
          # Set the logging timestamp to the time of the last snapshot
          # has to be in UTC and following the Day One required format
          options['datestamp'] = snapshot_date.new_offset(0).strftime('%FT%TZ')
        end
        options['content'] = sprintf("# Reporter\n\n%s\n\n%s", snapshots.join("\n---\n"), tags)
        sl = DayOne.new
        sl.to_dayone(options)
      end
    end
    # Ensure all entries is disabled after 1 run
    config['reporter_all_entries'] = false
    return config
  end

  # get the list of files that need to be parsed
  def get_filelist(config)
    inputDir = config['reporter_source_directory']
    if config['reporter_all_entries']
      Dir.chdir(inputDir)
      filelist = Dir.glob("*reporter-export.json")
    else
      days = $options[:timespan]
      $i = 0
      filelist = Array.new()
      until $i >= days do
        currentDate = Time.now - ((60 * 60 * 24) * $i)
        date = currentDate.strftime('%Y-%m-%d')
        filename = "#{inputDir}/#{date}-reporter-export.json"
        if File.exists?(filename)
          filelist.push(filename)
        end
        $i += 1
      end
    end
    return filelist
  end

  # Parse the location data
  def get_location(location)
    if !location.nil? && location.has_key?('placemark') && location['placemark'].has_key?('name')
      placemark = location['placemark']
      location = [placemark['name'], placemark['locality'], placemark['country']].join(', ')
      return sprintf("* Location: %s\n", location)
    else
      return ""
    end
  end

  # Parse the weather data
  def get_weather(weather, fahrenheit)
    if weather.nil?
      return ""
    end
    temperature = fahrenheit == true ? weather['tempF'] : weather['tempC']
    return sprintf("* Weather: %s (%.1f degrees)\n", weather['weather'], temperature)
  end

  # Parse the different types of responses
  def get_responses(responses)
    text = ''
    responses.each do |response|
      if response.has_key? 'textResponses'
        response_text = get_textresponse(response['textResponses'])
      elsif response.has_key? 'tokens'
        response_text = get_textresponse(response['tokens'])
      elsif response.has_key? 'numericResponse'
        response_text = response['numericResponse']
      elsif response.has_key? 'locationResponse'
        response_text = response['locationResponse']['text']
      elsif response.has_key? 'answeredOptions'
        response_text = response['answeredOptions'].join(", ")
      end
      text += sprintf("\n**%s**\n%s\n", response['questionPrompt'], response_text)
    end
    return text
  end

  # Collate possible multiple responses into a single text
  def get_textresponse(responses)
    response_list = Array.new()
    responses.each do |response|
      response_list.push(response['text'])
    end
    return response_list.join("\n")
  end
end

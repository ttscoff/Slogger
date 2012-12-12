=begin
Plugin: Facebook / IFTTT logger
Description: Parses Facebook posts logged by IFTTT.com
Author: [hargrove](https://github.com/spiritofnine)
Configuration:
  facebook_ifttt_input_file: "/path/to/dropbox/ifttt/facebook.txt"
Notes:
  - Configure IFTTT to log Facebook status posts to a text file.
  - You can use the recipe at https://ifttt.com/recipes/56242
  - and personalize if for your Dropbox set up.
  -
  - Unless you change it, the recipe will write to the following
  - location:
  -
  - {Dropbox path}/AppData/ifttt/facebook/facebook.md.txt
  -
  - You probably don't want that, so change it in the recipe accordingly.
  -
  - On a standard Dropbox install on OS X, the Dropbox path is
  -
  - /Users/username/Dropbox
  -
  - so the full path is:
  -
  - /Users/username/Dropbox/AppData/ifttt/facebook/facebook.md.txt
  -
  - You should set facebook_ifttt_input_file to this value, substituting username appropriately.
=end

config = {
  'description' => ['Parses Facebook posts logged by IFTTT.com',
                    'facebook_ifttt_input_file is a string pointing to the location of the file created by IFTTT.',
                    'The recipe at https://ifttt.com/recipes/56242 determines that location.'],
  'facebook_ifttt_input_file' => '',
  'facebook_ifttt_star' => false,
  'facebook_ifttt_tags' => '#social #blogging'
}

$slog.register_plugin({ 'class' => 'FacebookIFTTTLogger', 'config' => config })

class FacebookIFTTTLogger < Slogger
	require 'date'
	require 'time'

	def do_log
	    if @config.key?(self.class.name)
    	  config = @config[self.class.name]
      		if !config.key?('facebook_ifttt_input_file') || config['facebook_ifttt_input_file'] == []
        		@log.warn("FacebookIFTTTLogger has not been configured or an option is invalid, please edit your slogger_config file.")
        		return
      		end
    	else
      		@log.warn("FacebookIFTTTLogger has not been configured or a feed is invalid, please edit your slogger_config file.")
      	return
    end

    tags = config['facebook_ifttt_tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    inputFile = config['facebook_ifttt_input_file']

    @log.info("Logging FacebookIFTTTLogger posts at #{inputFile}")

    regPost = /^Post: /
    regDate = /^Date: /
    ampm    = /(AM|PM)\Z/
    pm      = /PM\Z/

    last_run = @timespan

    ready = false
    inpost = false
    posttext = ""

    options = {}
    options['starred'] = config['facebook_ifttt_star']

    f = File.new(File.expand_path(inputFile))
    content = f.read
    f.close

    if !content.empty?
      content.each do |line|
         if line =~ regDate
          inpost = false
          line = line.strip
          line = line.gsub(regDate, "")
          line = line.gsub(" at ", ' ')
          line = line.gsub(',', '')

          month, day, year, time = line.split
          hour,min = time.split(/:/)
          min = min.gsub(ampm, '')

          if line =~ pm
            x = hour.to_i
            x += 12
            hour = x.to_s
          end

          month = Date::MONTHNAMES.index(month)
          ltime = Time.local(year, month, day, hour, min, 0, 0)
          date = ltime.to_i

          if not date > last_run.to_i
            posttext = ""
            next
          end

          options['datestamp'] = ltime.utc.iso8601
          ready = true
  			 elsif line =~ regPost or inpost == true
            inpost = true
  			   	line = line.gsub(regPost, "")
            posttext += line
            ready = false
  		  end

        if ready
          sl = DayOne.new
          options['content'] = "#### FacebookIFTTT\n\n#{posttext}\n\n#{tags}"
          sl.to_dayone(options)
          ready = false
          posttext = ""
        end
      end
    end
  end
end

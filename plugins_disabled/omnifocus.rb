=begin
Plugin: OmniFocus
Description: Grabs completed tasks from OmniFocus
Author: [RichSomerfield](www.richsomerfield.com)
=end

config = {
  'omnifocus_description' => [
    'Grabs completed tasks from OmniFocus'],
  'omnifocus_tags' => '#tasks',
  'omnifocus_save_hashtags' => true,
  'omnifocus_folder_filter' => [],
}

$slog.register_plugin({ 'class' => 'OmniFocusLogger', 'config' => config })

class OmniFocusLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      filters = config['omnifocus_folder_filter'] || []
    else
      @log.warn("<Service> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging OmniFocus for completed tasks")

    additional_config_option = config['additional_config_option'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    timespan = @timespan.strftime('%d %b %Y')
    output = ''
    # Run an embedded applescript to get today's completed tasks

    if filters.empty? then
      filters = ["NONE", ]
    end

    for filter in filters
      values = %x{osascript <<'APPLESCRIPT'
        set filter to "#{filter}"
        set dteToday to date ("#{timespan}")
        tell application id "com.omnigroup.OmniFocus"
          tell default document
            if filter is equal to "NONE" then
              set refDoneToday to a reference to (flattened tasks where (completion date >= dteToday))
            else
              set refDoneToday to a reference to (flattened tasks where (completion date >= dteToday) and name of containing project's folder = filter)

            end if
            set {lstName, lstContext, lstProject} to {name, name of its context, name of its containing project} of refDoneToday
            set strText to ""
            repeat with iTask from 1 to count of lstName
              set {strName, varContext, varProject} to {item iTask of lstName, item iTask of lstContext, item iTask of lstProject}
              set strText to strText & strName
              if varContext is not missing value then set strText to strText & " @" & varContext
              if varProject is not missing value then set strText to strText & " (" & varProject & ")"
              set strText to strText & linefeed
            end repeat
          end tell
        end tell
        return strText
      APPLESCRIPT}
      unless values.strip.empty?
        unless filter == "NONE"
          output += "\n### Tasks in #{filter}\n"
        end
        values.squeeze("\n").each_line do |value|
          # Create entries here
          output += "* " + value
        end
        output += "\n"
        puts filter
      end
    end

    # Create a journal entry
    unless output == ''
      options = {}
      options['content'] = "## OmniFocus - Completed Tasks\n\n#{output}#{tags}"
      sl = DayOne.new
      sl.to_dayone(options)
    end
  end
end

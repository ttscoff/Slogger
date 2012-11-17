=begin
Plugin: OmniFocus
Description: Grabs completed tasks from OmniFocus
Author: [RichSomerfield](www.richsomerfield.com)
=end

config = {
  'omnifocus_description' => [
    'Grabs completed tasks from OmniFocus'],
  'omnifocus_tags' => '#tasks',
  'omnifocus_save_hashtags' => true
}

$slog.register_plugin({ 'class' => 'OmniFocusLogger', 'config' => config })

class OmniFocusLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      # We don't have any config, so don't need to worry about it not being there ;-)
    else
      @log.warn("<Service> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging <Service> for completed tasks")

    additional_config_option = config['additional_config_option'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    today = @timespan
    output = ''

    # Run an embedded applescript to get today's completed tasks
    values = %x{osascript <<'APPLESCRIPT'
      set dteToday to date (short date string of (current date))
      tell application id "com.omnigroup.OmniFocus"
        tell default document
          set refDoneToday to a reference to (flattened tasks where (completion date >= dteToday))
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
    values.squeeze("\n").each_line do |value|
      # Create entries here
      output += "* " + value
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

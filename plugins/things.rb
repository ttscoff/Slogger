=begin
Plugin: Things
Description: Grabs completed tasks from Things (code based on OminFocus plugin)
Author: Patrice Brend'amour 
=end

config = {
  'things_description' => [
    'Grabs completed tasks from Things'],
  'things_tags' => '#tasks',
}

$slog.register_plugin({ 'class' => 'ThingsLogger', 'config' => config })

class ThingsLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      # We don't have any config, so don't need to worry about it not being there ;-)
    else
      @log.warn("Things has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging Things for completed tasks")
    config = @config[self.class.name]
      
    tags = config['things_tags'] || ''
    tags = "\n\n#{tags}\n" unless tags == ''
    
      
    timespan = @timespan.strftime('%d/%m/%Y')
    output = ''
      
    # Run an embedded applescript to get today's completed tasks
    values = %x{osascript <<'APPLESCRIPT'
        set dteToday to setDate("#{timespan}")
        set completedTasks to ""
        tell application "Things"
        set todos to to dos
        set finishedProjects to {}
        repeat with todo in todos
		if status of todo is completed then
			set completionDateTime to completion date of todo
			set time of completionDateTime to 0
			if completionDateTime ≥ dteToday then
				set taskTitle to name of todo
				set taskProject to project of todo
				set taskArea to area of todo
				set taskTags to tag names of todo
				if completedTasks is not "" then set completedTasks to completedTasks & linefeed
                    
                    set completedTasks to completedTasks & taskTitle
                    set projectAreaString to ""
                    if taskArea is not missing value then set projectAreaString to projectAreaString & "Area: '" & name of taskArea & "'"
                        if taskProject is not missing value then set projectAreaString to projectAreaString & "Project: '" & name of taskProject & "'"
                            if projectAreaString is not "" then set completedTasks to completedTasks & " (" & projectAreaString & ")"
                                if taskTags is not "" then set completedTasks to completedTasks & " @" & taskTags
                                end if
                            end if
                        end repeat
                    end tell
                    return completedTasks
                    
                    on setDate(theDateStr)
                    set {TID, text item delimiters} to {text item delimiters, "/"}
                    set {dd, mm, yy, text item delimiters} to every text item in theDateStr & TID
                    set t to current date
                    set day of t to (dd as integer)
                    set month of t to (mm as integer)
                    set year of t to (yy as integer)
                    return t
                end setDate
                APPLESCRIPT}
                
    values.each_line(sep="\n") do |value|
      # Create entries here
        if value != "\n" then
            output += "* " + value
        end
    end

    # Create a journal entry
    if output != ''
      options = {}
      options['content'] = "## Things - Completed Tasks\n\n#{output}#{tags}"
      sl = DayOne.new
      sl.to_dayone(options)
    end
  end
end

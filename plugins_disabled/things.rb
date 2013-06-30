=begin
Plugin: Things
Description: Grabs completed tasks from Things
Notes: Thanks goes to RichSomerfield for the OmniFocus plugin, I used it as inspiration.
       things_project_filter is an optional string of a project name that should not be imported (e.g. my grocery list). If left empty, all tasks will be imported.
Author: [Brian Stearns](twitter.com/brs), Patrice Brend'amour
=end

config = {
  'things_description' => [
    'Grabs completed tasks from Things',
    'things_project_filter is an optional string of a project name that should not be imported (e.g. my grocery list). If left empty, all tasks will be imported.'],
  'things_tags' => '#tasks',
  'things_save_hashtags' => true,
  'things_project_filter' => '',
}

$slog.register_plugin({ 'class' => 'ThingsLogger', 'config' => config })

class ThingsLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      filter = config['things_project_filter'] || []
    else
      @log.warn("<Service> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging Things for completed tasks")

    # Unassigned Var
    #additional_config_option = config['additional_config_option'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    timespan = @timespan.strftime('%d/%m/%Y')
    output = ''
    # Run an embedded applescript to get today's completed tasks

    # if filters.empty? then
      # filters = ["NONE", ]
      # end

    #for filter in filters
      values = %x{osascript <<'APPLESCRIPT'
        set filter to "#{filter}"

        set dteToday to short date string of (setDate("#{timespan}"))

        set completedItems to ""
        tell application id "com.culturedcode.Things"

          -- Move all completed items to Logbook
          log completed now
        repeat with td in to dos of list "Logbook"
        			set tcd to the completion date of td
        			set dc to short date string of (tcd)
              repeat 1 times
              			if (project of td) is not missing value then
              				set aProject to project of td
              				set projectName to name of aProject

              				if projectName = filter then
              					exit repeat
              				end if
              			end if

              			if dc = dteToday then
              				set myName to name of td
            					set completedItems to completedItems & myName & linefeed
              			end if
              		end repeat
        	end repeat
        end tell
        return completedItems

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

      unless values.strip.empty?
        values.squeeze("\n").each_line do |value|
          # Create entries here
          output += "* " + value
        end
        output += "\n"
      end
      #end

    # Create a journal entry
    unless output == ''
      options = {}
      options['content'] = "## Things - Completed Tasks\n\n#{output}#{tags}"
      sl = DayOne.new
      sl.to_dayone(options)
    end
  end
end

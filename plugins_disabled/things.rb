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
    'things_project_filter is an optional string of a project name that should not be imported (e.g. my grocery list). If left empty, all tasks will be imported.',
    'things_collated allows you to switch between a single entry for all separate days (default) or separate entries for each'],
  'things_tags' => '#tasks',
  'things_save_hashtags' => true,
  'things_project_filter' => '',
  'things_collated' => true
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
    config['things_tags'] ||= ''
    tags = config['things_tags'] == '' ? '' : "\n\n#{config['things_tags']}\n"

    timespan = @timespan.strftime('%d/%m/%Y')
    output = ''
    separate_days = Hash.new
    # Run an embedded applescript to get today's completed tasks

    # if filters.empty? then
      # filters = ["NONE", ]
      # end

    #for filter in filters
      values = %x{osascript <<'APPLESCRIPT'
        set filter to "#{filter}"

        setDate("#{timespan}")

        set dteToday to date "#{timespan}"


        set completedItems to ""
        tell application id "com.culturedcode.Things"

          -- Move all completed items to Logbook
          log completed now
        repeat with td in to dos of list "Logbook"
              set tcd to the completion date of td
              set dc to my intlDateFormat(tcd)
              repeat 1 times
                    if (project of td) is not missing value then
                      set aProject to project of td
                      set projectName to name of aProject

                      if projectName = filter then
                        exit repeat
                      end if
                    end if

                    if tcd >= dteToday then
                      set myName to name of td
                      set completedItems to completedItems & dc & "-::-" & myName & linefeed
                    end if
                  end repeat
          end repeat
        end tell
        return completedItems

        on intlDateFormat(dt)
          set {year:y, month:m, day:d} to dt
          tell (y * 10000 + m * 100 + d) as string to text 1 thru 4 & "-" & text 5 thru 6 & "-" & text 7 thru 8
        end intlDateFormat

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
        # Create entries here
        values.squeeze("\n").each_line do |value|
          # -::- is used as a delimiter as it's unlikely to show up in a todo
          entry = value.split('-::-')
          # We set the date of the entries to 23:55 and format it correctly
          date_to_format = entry[0] + 'T23:55:00'
          todo_date = Time.strptime(date_to_format, '%Y-%m-%dT%H:%M:%S')
          formatted_date = todo_date.utc.iso8601

          # create an array for the uncollated entries
          todo_value = separate_days.fetch(formatted_date) { '' }
          todo_value += "* " + entry[1]
          separate_days[formatted_date] = todo_value

          # output is used to store for collated entries
          output += "* " + entry[1]
        end
      end
      #end

    # Create a collated journal entry
    if config['things_collated'] == true
      unless output == ''
        options = {}
        options['content'] = "## Things - Completed Tasks\n\n#{output}\n#{tags}"
        sl = DayOne.new
        sl.to_dayone(options)
      end
    else
      unless separate_days.empty?
        # Use reduce instead of each to prevent entries from polluting the config file
        separate_days.reduce('') do | s, (entry_date, entry)|
          options = {}
          options['datestamp'] = entry_date
          options['content'] = "## Things - Completed Tasks\n\n#{entry}\n#{tags}"
          sl = DayOne.new
          sl.to_dayone(options)
        end
      end
    end
  end
end

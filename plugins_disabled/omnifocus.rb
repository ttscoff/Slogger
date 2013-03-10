=begin
Plugin: OmniFocus
Description: Grabs completed tasks from OmniFocus
Notes: omnifocus_folder_filter is an optional array of folders that should be
  included. If empty, all tasks will be imported. Only the immediate ancestor
  folder will be considered, so if you have a stucture like:
    - Work
      - Client 1
      - Client 2
  You'll have to add "Client 1" and "Client 2" - "Work" will not return anything
  in the Client folders, only projects and tasks directly inside the Work
  folder.
Author: [RichSomerfield](www.richsomerfield.com)
=end

config = {
  'omnifocus_description' => [
    'Grabs completed tasks from OmniFocus',
    'omnifocus_folder_filter is an optional array of folders that should be included. If left empty, all tasks will be imported.'],
  'omnifocus_tags' => '#tasks',
  'omnifocus_save_hashtags' => true,
  'omnifocus_completed_tasks' => true,
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
    omnifocus_completed_tasks = config['omnifocus_completed_tasks'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    timespan = @timespan.strftime('%d/%m/%Y')
    output = ''
    # Run an embedded applescript to get today's completed tasks

    if filters.empty? then
      filters = ["NONE", ]
    end

    for filter in filters
      values = %x{osascript <<'APPLESCRIPT'
        set filter to "#{filter}"
        set dteToday to setDate("#{timespan}")
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
                                                  
      on setDate(theDateStr)
         set {TID, text item delimiters} to {text item delimiters, "/"}
         set {dd, mm, yy, text item delimiters} to every text item in theDateStr & TID
         set t to current date
         set year of t to (yy as integer)
         set month of t to (mm as integer)
         set day of t to (dd as integer)
         return t
      end setDate
      APPLESCRIPT}
      unless values.strip.empty?
        unless filter == "NONE"
          output += "\n### Tasks in #{filter}\n"
        end
        tasks_completed = 0
        values.squeeze("\n").each_line do |value|
          # Create entries here
          tasks_completed += 1
          #ensures that only valid characters are saved to output
        
          #this only works in newer ruby versions but not in the default 1.8.7
          begin
              value = value.chars.select{|i| i.valid_encoding?}.join
          rescue
          end
          
          output += "* " + value
        end
        output += "\n"
      end
    end
    #If omnifocus_completed_tasks is true then set text for insertion
    if omnifocus_completed_tasks then
      text_completed = "#{tasks_completed} tasks completed today! \n\n"
    end

    # Create a journal entry
    unless output == ''
      options = {}
      options['content'] = "## OmniFocus - Completed Tasks\n\n#{text_completed}#{output}#{tags}"
      sl = DayOne.new
      sl.to_dayone(options)
    end
  end
end

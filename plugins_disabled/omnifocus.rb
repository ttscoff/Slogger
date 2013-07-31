=begin
Plugin: OmniFocus
Version: 1.3
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
Author: [RichSomerfield](www.richsomerfield.com) & [Patrice Brend'amour](brendamour.de)
=end

config = {
  'omnifocus_description' => [
    'Grabs completed tasks from OmniFocus',
    'omnifocus_folder_filter is an optional array of folders that should be included. If left empty, all tasks will be imported.'],
  'omnifocus_tags' => '#tasks',
  'omnifocus_save_hashtags' => true,
  'omnifocus_completed_tasks' => true,
  'omnifocus_log_notes' => false,
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
    log_notes = config['omnifocus_log_notes'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    
    output = ''
    developMode = $options[:develop]
    
    
    # Run an embedded applescript to get today's completed tasks

    if filters.empty? then
      filters = ["NONE", ]
    end

    # ============================================================
    # iterate over the days and create entries
    $i = 0
    days = $options[:timespan]
    if developMode
        @log.info("Running plugin for the last #{days} days")
    end
    
    until $i >= days  do
      currentDate = Time.now - ((60 * 60 * 24) * $i)
      timestring = currentDate.strftime('%d/%m/%Y')
      
      if developMode
          @log.info("Running plugin for #{timestring}")
      end
      
      for filter in filters
        values = %x{osascript <<'APPLESCRIPT'
          set filter to "#{filter}"
          set dteToday to setDate("#{timestring}")
          tell application id "com.omnigroup.OmniFocus"
          	tell default document
          		if filter is equal to "NONE" then
          			set refDoneToday to a reference to (flattened tasks where (completion date ≥ dteToday))
          		else
          			set refDoneToday to a reference to (flattened tasks where (completion date ≥ dteToday) and name of containing project's folder = filter)
			
          		end if
          		set {lstName, lstContext, lstProject, lstNote} to {name, name of its context, name of its containing project, note} of refDoneToday
          		set strText to ""
		
          		set numberOfItems to count of lstName
          		repeat with iTask from 1 to numberOfItems
          			set {strName, varContext, varProject, varNote} to {item iTask of lstName, item iTask of lstContext, item iTask of lstProject, item iTask of lstNote}
			
          			set contextString to "null"
          			set projectString to "null"
          			set noteString to "null"
          			if varContext is not missing value then set contextString to varContext
          			if varProject is not missing value then set projectString to varProject
          			if varNote is not missing value then set noteString to varNote
			
          			set noteString to my replaceText(noteString, linefeed, "\\\\n")
			
          			set delimiterString to "##__##"
			
          			set strText to strText & strName & delimiterString & projectString & delimiterString & contextString & delimiterString & noteString & linefeed
			
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

          to replaceText(someText, oldItem, newItem)
          	(*
               replace all occurances of oldItem with newItem
                    parameters -     someText [text]: the text containing the item(s) to change
                              oldItem [text, list of text]: the item to be replaced
                              newItem [text]: the item to replace with
                    returns [text]:     the text with the item(s) replaced
               *)
          	set {tempTID, AppleScript's text item delimiters} to {AppleScript's text item delimiters, oldItem}
          	try
          		set {itemList, AppleScript's text item delimiters} to {text items of someText, newItem}
          		set {someText, AppleScript's text item delimiters} to {itemList as text, tempTID}
          	on error errorMessage number errorNumber -- oops
          		set AppleScript's text item delimiters to tempTID
          		error errorMessage number errorNumber -- pass it on
          	end try
	
          	return someText
          end replaceText
        APPLESCRIPT}
        
        unless values.strip.empty?
          unless filter == "NONE"
            output += "\n## Tasks in #{filter}\n"
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
            
            name, project, context, note = value.split("##__##")
  
            taskString = "## #{name}\n "
            
            if context != "null"
              taskString += "*Context:* #{context} \n"
            end
            if project != "null"
              taskString += "*Project:* #{project}\n"
            end
            if note != "null" && log_notes
              note = note.gsub("\\n","\n> ")
              taskString += "*Notes:*\n> #{note}"
            end
               
            output += taskString
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
        options['content'] = "# OmniFocus - Completed Tasks\n\n#{text_completed}#{output}#{tags}"
        sl = DayOne.new
        sl.to_dayone(options)
      end
      $i += 1
    end
    return config
  end
end

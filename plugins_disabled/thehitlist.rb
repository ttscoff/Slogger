=begin
Plugin: The Hit List
Description: Grabs completed tasks from The Hit List
Notes: Based on the Things plugin by [Brian Stearns](twitter.com/brs), Patrice Brend'amour
Author: David Hutchison (www.devwithimagination.com)
=end

config = {
  'thishitlist_description' => [
    'Grabs completed tasks from The Hit List'],
  'thehitlist_tags' => '#tasks',
  'thehitlist_save_hashtags' => true
}

$slog.register_plugin({ 'class' => 'TheHitListLogger', 'config' => config })

class TheHitListLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
    else
      @log.warn("<Service> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging The Hit List for completed tasks")

    # Unassigned Var
    #additional_config_option = config['additional_config_option'] || false
    config['thehitlist_tags'] ||= ''
    tags = config['thehitlist_tags'] == '' ? '' : "\n\n(#{config['thehitlist_tags']})\n"

    datespan = @timespan.strftime('%d/%m/%Y')
    timespan = @timespan.strftime('%H:%M:%S')
    output = ''
    separate_days = Hash.new
    # Run an embedded applescript to get today's completed tasks

    #for filter in filters
    values = %x{osascript <<'APPLESCRIPT'
        # set up the filter
        set today to the current date
        set theFilterStart to setTime(setDate("#{datespan}"), "#{timespan}")
        
        # Setup the empty string for building up
        set completedText to ""

        tell application "The Hit List"
            
        # Looping through each date
        repeat while (theFilterStart < today)
            
            copy theFilterStart to theFilterEnd
            set theFilterEnd to my setTime(theFilterEnd, "23:59:59")
            set dc to my intlDateFormat(theFilterStart)
            set thisDayText to ""
            
            # Loop through all the folders, building up a string
            # of completed tasks as we go
            set folderlist to folders in folders group
            repeat with singleFolder in folderlist
                
                set foldername to the name of singleFolder
                
                set thisItemText to ""
                if the class of singleFolder is folder then
                    set thisItemText to my processFolder(theFilterStart, theFilterEnd, "", singleFolder)
                else if the class of singleFolder is list then
                    set thisItemText to my processList(theFilterStart, theFilterEnd, "", singleFolder)
                end if
                
                set thisDayText to my appendTextIfNeeded(thisItemText, thisDayText, linefeed)
                
            end repeat
            
            if (length of thisDayText > 0) then
                set completedText to completedText & "|||" & dc & "-::-" & thisDayText & linefeed
            end if
            
            
            set theFilterStart to my setTime((theFilterStart + (1 * days)), "00:00:00")
        end repeat
        
    end tell
    return completedText
    
    # Get a string containing the details of any tasks which have been
    # completed in the supplied time frame. This includes any
    # sub tasks of this parent task.
    # theFilterStartDate: the start of the filter range
    # theFilterEndDate: the end of the filter range
    # folderPath: The path to this task already
    # singleFolder: The folder to process.
    on processFolder(theFilterStartDate, theFilterEndDate, folderPath, singleFolder)
        
        tell application "The Hit List"
            
            # Setup the empty string for building up
            set completedText to ""
            
            # Set up the title for anything which is found here
            set newPath to ""
            if length of folderPath is greater than 0 then
                set newPath to folderPath & " -> "
            end if
            set newPath to newPath & (name of singleFolder)
            
            # Loop through each item building up the completed items
            # as we go
            set itemList to every folder in singleFolder
            repeat with singleItem in itemList
                
                set thisItemText to ""
                if the class of singleItem is folder then
                    set thisItemText to my processFolder(theFilterStartDate, theFilterEndDate, newPath, singleItem)
                else if the class of singleItem is list then
                    set thisItemText to my processList(theFilterStartDate, theFilterEndDate, newPath, singleItem)
                end if
                
                set completedText to my appendTextIfNeeded(thisItemText, completedText, linefeed)
            end repeat
            
            return completedText
            
        end tell
    end processFolder
    
    # Get a string containing the details of any tasks which have been
    # completed in the supplied time frame. 
    # theFilterStartDate: the start of the filter range
    # theFilterEndDate: the end of the filter range
    # listPath: The path to this task already
    # theList: The list to process.
    on processList(theFilterStartDate, theFilterEndDate, listPath, theList)
        
        tell application "The Hit List"
            
            set listText to ""
            
            # Loop through each task in the list checking if they are 
            # complete, and build up a string of these items.
            set taskList to every task in theList
            repeat with thisTask in taskList
                set thisTaskText to my processTask(theFilterStartDate, theFilterEndDate, listPath, thisTask, "")
                set listText to my appendTextIfNeeded(thisTaskText, listText, "")
            end repeat
            
            # If this text has some completed items then add a header to this
            if length of listText > 0 then
                set listHeader to "### " & listPath & " -> " & (name of theList)
                set listText to (listHeader & linefeed & listText)
            end if
            
            return listText
        end tell
        
    end processList
    
    # Get a string containing the details of any tasks which have been
    # completed in the supplied time frame. This includes any
    # sub tasks of this parent task.
    # theFilterStartDate: the start of the filter range
    # theFilterEndDate: the end of the filter range
    # taskPath: The path to this task already
    # theTask: The task to process.
    # separator: any separator which should be added before appending the task text
    on processTask(theFilterStartDate, theFilterEndDate, taskPath, theTask, separator)
        
        tell application "The Hit List"
            
            set taskPrefix to separator & "- "
            set taskTitle to (the timing task of theTask)
            set taskText to ""
            set completedThisDay to false
            
            # If this task is completed, add it to the text 
            if theTask is completed then
                set taskCompletionDate to the completed date of theTask
                if taskCompletionDate ≥ theFilterStartDate and taskCompletionDate ≤ theFilterEndDate then
                    set completedThisDay to true
                    set theTime to (my zeroPadNumber(hours of taskCompletionDate)) & ":" & (my zeroPadNumber(minutes of taskCompletionDate))
                    set taskText to taskPrefix & "\\"" & taskTitle & "\\" was completed at " & theTime
                end if
            end if
            
            # Loop through each sub task and check if it is complete. 
		    # Only need to do this if this task is incomplete, or completed this day
		    if (theTask is not completed) or (completedThisDay is true) then
                set subtaskText to ""
                set newSeparator to "    " & separator
                set subtasks to every task in theTask
                repeat with thisTask in subtasks
                    set thisSubtaskText to my processTask(theFilterStartDate, theFilterEndDate, taskPath, thisTask, newSeparator)
                    set subtaskText to my appendTextIfNeeded(thisSubtaskText, subtaskText, "")
                end repeat
            
                # If this task is not complete and some subtasks are, 
                # add the task title to the text
                if (length of subtaskText > 0) and (length of taskText = 0) then
                    set taskText to taskPrefix & taskTitle & linefeed & subtaskText
                else if (length of subtaskText > 0) then
                    set taskText to taskText & linefeed & subtaskText
                end if
            end if
            
            return taskText
            
        end tell
    end processTask
    
    # Return a string contining the existing text with the "newText" value appended, 
    # if it is non-empty.
    # newText: the new text to add
    # existingText: the text which already exists
    # lineSeparator: any separator which should be added after a new line 
    on appendTextIfNeeded(newText, existingText, lineSeparator)
        
        set newCompletedText to existingText
        if (length of newText > 0 and length of existingText > 0) then
            set newCompletedText to existingText & linefeed & lineSeparator
        end if
        if (length of newText > 0) then
            set newCompletedText to newCompletedText & newText
        end if
        
        return newCompletedText
        
    end appendTextIfNeeded
    
    on intlDateFormat(dt)
        set {year:y, month:m, day:d} to dt
        tell (y * 10000 + m * 100 + d) as string to text 1 thru 4 & "-" & text 5 thru 6 & "-" & text 7 thru 8
    end intlDateFormat
    
    # Parse the suppled date in dd/mm/yy format into a date.
    on setDate(theDateStr)
        set {TID, text item delimiters} to {text item delimiters, "/"}
        set {dd, mm, yy, text item delimiters} to every text item in theDateStr & TID
        set t to current date
        set day of t to (dd as integer)
        set month of t to (mm as integer)
        set year of t to (yy as integer)
        set hours of t to 0
        set minutes of t to 0
        set seconds of t to 0
        return t
    end setDate
    
    # Parses theTimeStr splitting it by the ':' characters and set a time component on to
    # a copy of theDate.
    on setTime(theDate, theTimeStr)
        set {TID, text item delimiters} to {text item delimiters, ":"}
        set {hh, mm, ss, text item delimiters} to every text item in theTimeStr & TID
        copy theDate to t
        set hours of t to (hh as integer)
        set minutes of t to (mm as integer)
        set seconds of t to (ss as integer)
        return t
    end setTime
    
    # Pads a number so it is zero padded to two numbers
    # theNumber: the number to zero pad
    on zeroPadNumber(theNumber)
        return (text -2 thru -1 of ("00" & theNumber))
    end zeroPadNumber

    APPLESCRIPT}

    unless values.strip.empty?
    
      puts values
      
      singleEntries = values.split('|||')
      
      # Split into single day parts
      singleEntries.each do |value|
      
        if !value.empty?
          puts 'Doing something...'
          # -::- is used as a delimiter as it's unlikely to show up in a todo
          entry = value.split('-::-')
          # We set the date of the entries to 23:55 and format it correctly
          date_to_format = entry[0] + 'T23:55:00'
          todo_date = Time.strptime(date_to_format, '%Y-%m-%dT%H:%M:%S')
          formatted_date = todo_date.utc.iso8601
          
          # create an array for the uncollated entries
          todo_value = entry[1]
          
          puts date_to_format
          puts todo_value
          
          separate_days[formatted_date] = todo_value
        end
      end
    end
    
    # Add these to day one
    unless separate_days.empty?
      # Use reduce instead of each to prevent entries from polluting the config file
      separate_days.reduce('') do | s, (entry_date, entry)|
        options = {}
        options['datestamp'] = entry_date
        options['content'] = "## The Hit List - Completed Tasks\n\n#{entry}\n#{tags}"
        puts options
        sl = DayOne.new
        sl.to_dayone(options)
      end
    end
  end
end
#!/usr/bin/ruby

curloc = File.expand_path(File.dirname(__FILE__))
unless File.exists?(curloc+'/slogger_config')
	puts
	puts "Please run `#{curloc}/slogger` once to generate the configuration file."
	puts
	puts "The file will show up in your slogger folder, and you can edit usernames"
	puts "and options in it. Once you're done, run this installer again."
	exit
end

puts
puts "Installing Slogger logging scheduler"
puts "This script will install the following files:"
puts "~/Library/LaunchAgents/com.brettterpstra.slogger.plist"
puts
puts "Is '#{curloc}' the location of your Slogger folder?"
print "(Y/n)"
ans = gets.chomp
if ans.downcase == "n"
	puts "Please enter the path to the 'slogger' folder on your drive"
	print "> "
	dir = gets.chomp
else
	dir = curloc
end

if File.exists?(dir+"/slogger")
	flags = ""
	puts "By default, Slogger runs once a day at 11:50PM."
	puts "If your computer is not always on, you can have"
	puts "Slogger fetch data back to the time of the last"
	puts "successful run."
	puts
	puts "Is your Mac routinely offline at 11:50PM?"
	print "(Y/n)"
	ans = gets.chomp
	flags += " -s" if ans.downcase == "y"

	print "Setting up launchd... "
	xml=<<LAUNCHCTLPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.brettterpstra.Slogger</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/ruby</string>
		<string>#{dir}/slogger#{flags}</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Hour</key>
		<integer>23</integer>
		<key>Minute</key>
		<integer>50</integer>
	</dict>
</dict>
</plist>
LAUNCHCTLPLIST

	target_dir = File.expand_path("~/Library/LaunchAgents")
	target_file = File.expand_path(target_dir+"/com.brettterpstra.slogger.plist")

	Dir.mkdir(target_dir) unless File.exists?(target_dir)

	open(target_file,'w') { |f|
		f.puts xml
	} unless File.exists?(target_file)

	%x{launchctl load "#{target_file}"}
	puts "done!"
	puts
	puts "----------------------"
	puts "Installation complete."

else
	puts "Slogger doesn't appear to exist in the directory specified."
	puts "Please check your file location and try again."
end

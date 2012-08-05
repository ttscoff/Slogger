#!/usr/bin/ruby

if RUBY_VERSION.to_f < 1.9
	require 'fileutils'
else
	require 'ftools'
end

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
		<string>#{dir}/slogger</string>
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

File.makedirs(File.expand_path("~/Library/LaunchAgents")) unless File.exists?(File.expand_path("~/Library/LaunchAgents"))

open(File.expand_path("~/Library/LaunchAgents/com.brettterpstra.slogger.plist"),'w') { |f|
	f.puts xml
} unless File.exists?(File.expand_path("~/Library/LaunchAgents/com.brettterpstra.slogger.plist"))

%x{launchctl load #{File.expand_path("~/Library/LaunchAgents/com.brettterpstra.slogger.plist")}}
puts "done!"
puts
puts "----------------------"
puts "Installation complete."

else
	puts "Slogger doesn't appear to exist in the directory specified. Please check your file location and try again."
end

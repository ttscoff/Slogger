#!/usr/bin/env ruby
#    __  _
#   / _\| | ___   __ _  __ _  ___ _ __
#   \ \ | |/ _ \ / _` |/ _` |/ _ \ '__|
#   _\ \| | (_) | (_| | (_| |  __/ |
#   \__/|_|\___/ \__, |\__, |\___|_|
#                |___/ |___/
#        Copyright 2012, Brett Terpstra
#              http://brettterpstra.com
#                  --------------------
require 'rubygems'
require 'bundler/setup'
require 'open-uri'
require 'net/http'
require 'net/https'
require 'time'
require 'cgi'
require 'rss'
require 'erb'
require 'logger'
require 'optparse'
require 'fileutils'
require 'rexml/parsers/pullparser'
require 'rubygems'
require 'json'

SLOGGER_HOME = File.dirname(File.expand_path(__FILE__))
ENV['SLOGGER_HOME'] = SLOGGER_HOME

require SLOGGER_HOME + '/lib/sociallogger'
require SLOGGER_HOME + '/lib/configtools'
require SLOGGER_HOME + '/lib/plist.rb'
# require SLOGGER_HOME + '/lib/json'
require SLOGGER_HOME + '/lib/levenshtein-0.2.2/lib/levenshtein.rb'

if RUBY_VERSION.to_f > 1.9
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

class String
  def markdownify
    contents = ''
    begin
      if RUBY_VERSION.to_f > 1.9
        input = self.dup.force_encoding('utf-8')
      else
        input = self.dup
      end

      IO.popen('"$SLOGGER_HOME/lib/html2text"', "r+") do |io|
        begin
          Thread.new { input.each_line { |line|
            io << line
          }; io.close_write }
        rescue Exception => e
          $stderr.puts e
        end
        begin
          io.each_line do |line|
            contents << line
          end
        rescue Exception => e
          $stderr.puts e
        end
      end
      contents
    rescue Exception => e
      $stderr.puts e
      $stderr.puts "Error in Markdownify"
      self
    end
  end

  # convert (multi)Markdown to HTML
  def to_html
    md = SLOGGER_HOME + '/lib/multimarkdown'
    return %x{echo #{self.e_sh}|"#{md}"}
  end

  # shell escape for passing content to external commands
  # e.g. %x{echo content.e_sh|sort}
  def e_sh
    self.to_s.gsub(/(?=[^a-zA-Z0-9_.\/\-\n])/, '\\').gsub(/\n/, "'\n'").sub(/^$/, "''")
  end

  def e_link
    self.to_s.gsub(/([\[\]\(\)])/, '\\\\\1')
  end

  # escape text for use in a quoted AppleScript string
  #
  # string = %q{"This is a quoted string and it's awfully nice!"}
  # res = %x{osascript <<'APPLESCRIPT'
  #   return "hello, #{string.e_as}"
  # APPLESCRIPT}
  def e_as(str)
    str.to_s.gsub(/(?=["\\])/, '\\')
  end

  def truncate_html(len = 30)
    p = REXML::Parsers::PullParser.new(self)
    tags = []
    new_len = len
    results = ''
    while p.has_next? && new_len > 0
      p_e = p.pull
      case p_e.event_type
      when :start_element
        tags.push p_e[0]
        results << "<#{tags.last} #{attrs_to_s(p_e[1])}>"
      when :end_element
        results << "</#{tags.pop}>"
      when :text
        results << p_e[0].first(new_len)
        new_len -= p_e[0].length
      else
        results << "<!-- #{p_e.inspect} -->"
      end
    end
    tags.reverse.each do |tag|
      results << "</#{tag}>"
    end
    results
  end

  private

  def attrs_to_s(attrs)
    if attrs.empty?
      ''
    else
      attrs.to_a.map { |attr| %{#{attr[0]}="#{attr[1]}"} }.join(' ')
    end
  end
end

class SloggerUtils
  def get_stdin(message)
    print message + " "
    STDIN.gets.chomp
  end

  def ask(message, valid_options = nil)
    if valid_options
      answer = get_stdin("#{message} #{valid_options.to_s.gsub(/"/, '').gsub(/, /,'/')} ") while !valid_options.include?(answer)
    else
      answer = get_stdin(message)
    end
    answer
  end
end

class Slogger

  attr_accessor :config, :dayonepath, :plugins
  attr_reader :timespan, :log
  def initialize
    cfg = ConfigTools.new({'config_file' => $options[:config_file]})
    @log = Logger.new(STDERR)
    original_formatter = Logger::Formatter.new
    @log.datetime_format = '%d'
    @log.level = 1
    @log.progname = self.class.name
    @log.formatter = proc { |severity, datetime, progname, msg|
      abbr_sev = case severity
        when 'WARN' then "> "
        when 'ERROR' then "! "
        when 'FATAL' then "!!"
        else "  "
      end
      spacer_count = 20 - progname.length
      spacer = ''
      spacer_count.times do
        spacer += ' '
      end
      output = $options[:quiet] ? '' : "#{abbr_sev}#{datetime.strftime('%H:%M:%S')} #{spacer}#{progname}: #{msg}\n"
      output
    }

    @plugins = []

    if cfg.config_exists?
      @config = cfg.load_config
      if @config.nil?
        raise "Config should not be nil"
        Process.exit(-1)
      end
    end
    if $options[:since_last_run] && @config.key?('last_run_time') && !@config['last_run_time'].nil?
      @timespan = Time.parse(@config['last_run_time'])
    else
      @timespan = Time.now - ((60 * 60 * 24) * $options[:timespan])
    end
    @config['image_filename_is_title'] ||= false
    @dayonepath = self.storage_path
    @template = self.template
    @date_format = @config['date_format'] || '%F'
    @time_format = @config['time_format'] || '%R'
    @datetime_format = "#{@date_format} #{@time_format}"
  end

  def undo_slogger(count = 1)
    runlog = SLOGGER_HOME+'/runlog.txt'
    if File.exists?(runlog)
      undo_to = ''
      File.open(runlog,'r') do |f|
        runs = f.read.split(/\n/)
        if runs.length >= count
          undo_to = runs[count*-1].match(/^\[(.*?)\]/)[1]
        end
      end
      $stderr.puts undo_to
      tnow = Time.now
      elapsed = tnow - Time.parse(undo_to) # elapsed time in seconds
      files = %x{find "#{self.storage_path}" -newerct '#{elapsed.floor} seconds ago' -type f}.split(/\n/)
      files.each do |file|
        FileUtils.mv(file,ENV['HOME']+'/.Trash/')
      end
      @log.info("Moved #{files.length} entries to Trash")
    else
      @log.fatal("Run log does not exist.")
      Process.exit(-1)
    end
  end

  def log_run
    File.open(SLOGGER_HOME+'/runlog.txt', 'a') { |f|
      f.puts "[#{Time.now.strftime('%c')}] Slogger v#{MAJOR_VERSION} (#{MAJOR_VERSION}.#{MINOR_VERSION}.#{BUILD_NUMBER}) #{$options.inspect}"
    }
  end

  def storage_path
  	if @config.key?('storage')
	    if @config['storage'].downcase == 'icloud'
	      dayonedir = %x{ls ~/Library/Mobile\\ Documents/|grep dayoneapp}.strip
	      full_path = File.expand_path("~/Library/Mobile\ Documents/#{dayonedir}/Documents/Journal_dayone/")
	      if File.exists?(full_path)
	        return full_path
	      else
	        raise "Failed to find iCloud storage path"
	        Process.exit(-1)
	      end
	    elsif File.exists?(File.expand_path(@config['storage']))
	      return File.expand_path(@config['storage'])
	    else
        raise "Path for Day One journal is not specified or doesn't exist. Change your path in slogger_config and run ./slogger again: #{@config['storage']}"
	      Process.exit(-1)
	    end
	else
	  raise "Path for Day One journal is not specified or doesn't exist. Change your path in slogger_config and run ./slogger again: #{@config['storage']}"
	  return
	end
  end

  def run_plugins
    @config['last_run_time'] = Time.now.strftime('%c')
    new_options = false
    plugin_dir = $options[:develop] ? "/plugins_develop/*.rb" : "/plugins/*.rb"
    Dir[SLOGGER_HOME + plugin_dir].each do |file|
      if $options[:onlyrun]
        $options[:onlyrun].each { |plugin_frag|
          if File.basename(file) =~ /^#{plugin_frag}/i
            require file
          end
        }
      else
        require file
      end
    end
    @plugins.each do |plugin|
      _namespace = plugin['class'].to_s

      @config[_namespace] ||= {}
      plugin['config'].each do |k,v|
        if @config[_namespace][k].nil?
          new_options = true
          @config[_namespace][k] ||= v
        end
        @config[_namespace][_namespace+"_last_run"] = Time.now.strftime('%c')
      end
      unless $options[:config_only]
        # credit to Hilton Lipschitz (@hiltmon)
        updated_config = eval(plugin['class']).new.do_log
        if updated_config && updated_config.class.to_s == 'Hash'
            updated_config.each { |k,v|
              @config[_namespace][k] = v
            }
        end
      end
    end
    ConfigTools.new({'config_file' => $options[:config_file]}).dump_config(@config)
  end

  def register_plugin(plugin)
    @plugins.push plugin
  end

  def template
    markdown = @dayonepath =~ /Journal[\._]dayone\/?$/ ? false : true

    unless markdown
      ERB.new <<-XMLTEMPLATE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Creation Date</key>
  <date><%= datestamp %></date>
  <key>Creator</key>
  <dict>
    <key>Software Agent</key>
    <string>Slogger/#{MAJOR_VERSION}.#{MINOR_VERSION}.#{BUILD_NUMBER}</string>
  </dict>
  <key>Entry Text</key>
  <string><%= entry %></string>
  <% if location %><key>Location</key>
  <dict>
  <key>Administrative Area</key>
  <string></string>
  <key>Country</key>
  <string></string>
  <key>Latitude</key>
  <real><%= lat %></real>
  <key>Longitude</key>
  <real><%= long %></real>
  <key>Place Name</key>
  <string><% if place %><%= place %><% end %></string>
  </dict><% end %>
  <key>Starred</key>
  <<%= starred %>/>
  <% if tags %><key>Tags</key>
  <array>
  <% tags.each do |tag| %>  <string><%= tag %></string>
  <% end %></array><% end %>
  <key>UUID</key>
  <string><%= uuid %></string>
</dict>
</plist>
XMLTEMPLATE
    else
      ERB.new <<-MARKDOWNTEMPLATE
Title: Journal entry for <%= datestamp %>
Date: <%= datestamp %>
Starred: <%= starred %>
<% if tags %>Tags: <% tags.join(", ") %>  <% end %>

<%= entry %>

MARKDOWNTEMPLATE
    end
  end
end

require SLOGGER_HOME + '/lib/redirect'
require SLOGGER_HOME + '/lib/dayone'

$options = {}
optparse = OptionParser.new do|opts|
  opts.banner = "Usage: slogger [-dq] [-r X] [/path/to/image.jpg]"
  $options[:config_file] = File.expand_path(File.dirname(__FILE__)+'/slogger_config')
  opts.on('--update-config', 'Create or update a configuration file') do
    $options[:config_only] = true
  end
  opts.on( '-c', '--config FILE', 'Specify configuration file to use') do |file|
    file = File.expand_path(file)
    $options[:config_file] = file
  end
  $options[:develop] = false
  opts.on( '-d','--develop', 'Develop mode' ) do
    $options[:develop] = true
  end
  $options[:onlyrun] = false
  opts.on( '-o','--onlyrun NAME','Only run plugins matching items in comma-delimited string') do |plugin_string|
    $options[:onlyrun] = plugin_string.split(/,/).map {|frag| frag.strip }
  end
  $options[:timespan] = 1
  opts.on( '-t', '--timespan DAYS', 'Days of history to collect') do |days|
    $options[:timespan] = days.to_i
  end
  $options[:quiet] = false
  opts.on( '-q','--quiet', 'Run quietly (no notifications/messages)' ) do
   $options[:quiet] = true
  end
  $options[:max_retries] = 3
  opts.on( '-r','--retries COUNT', 'Maximum number of retries per plugin (int)' ) do |count|
    $options[:max_retries] = count.to_i
  end
  $options[:since_last_run] = false
  opts.on( '-s','--since-last', 'Set the timespan to the last run date' ) do
   $options[:since_last_run] = true
  end
  $options[:undo] = false
  opts.on( '-u', '--undo COUNT', 'Undo the last COUNT runs') do |count|
    $options[:undo] = count.to_i
  end
  opts.on( '-v', '--version', 'Display the version number') do
    $stdout.puts("Slogger version #{MAJOR_VERSION}.#{MINOR_VERSION}.#{BUILD_NUMBER}")
    exit
  end
  opts.on( '--dedup', 'Remove duplicate entries from Journal') do
    puts "This will remove entries from your Journal that have"
    puts "duplicate content and matching tags. The oldest copy"
    puts "of an entry will be preserved. The entries will be"
    puts "moved to a DayOneDuplicates directory on your Desktop."
    puts
    answer = SloggerUtils.new.ask("Are you sure you want to continue?",["y","n"])
    if answer == "y"
      DayOne.new.dedup
    end
    exit
  end
  ## This will be cool when it works.
  # opts.on( '--dedup_similar', 'Remove similar entries from Journal') do
  #   puts "This will remove entries from your Journal that have"
  #   puts "very similar content on the same date. The oldest copy"
  #   puts "of an entry will be preserved. The entries will be"
  #   puts "moved to a DayOneDuplicates directory on your Desktop."
  #   puts
  #   puts "This is a slow process and can take >15m on large journals."
  #   puts
  #   answer = SloggerUtils.new.ask("Are you sure you want to continue?",["y","n"])
  #   if answer == "y"
  #     DayOne.new.dedup(true)
  #   end
  #   exit
  # end
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!

$slog = Slogger.new
$slog.dayonepath = $slog.storage_path

if ARGV.length > 0
  path = File.expand_path(ARGV[0])
  if File.exists?(path)
    unless path =~ /\.(jpg|png|gif)/i
      File.open(path,'r') do | f |
        DayOne.new.to_dayone({ 'content' => f.read })
      end
    else
      DayOne.new.store_single_photo(ARGV[0],{},true)
    end
  else
    raise "File \"#{ARGV[0]}\" not found."
  end
else
  unless $options[:undo]
    # Set environment variable SLOGGER_NO_INITIALIZE if you want to load slogger config but not run plugins
    if ENV['SLOGGER_NO_INITIALIZE'] == "true"
      $stderr.puts "No initialization: Slogger v#{MAJOR_VERSION} (#{MAJOR_VERSION}.#{MINOR_VERSION}.#{BUILD_NUMBER})"
    else
      $stdout.puts "Initializing Slogger v#{MAJOR_VERSION} (#{MAJOR_VERSION}.#{MINOR_VERSION}.#{BUILD_NUMBER})..."
      $slog.log_run
      $slog.run_plugins
    end
  else
    $stdout.puts "Undoing the last #{$options[:undo].to_s} runs..."
    $slog.undo_slogger($options[:undo])
  end
end

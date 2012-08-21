#!/usr/bin/env ruby

require 'open-uri'
require 'net/http'
require 'net/https'
require 'time'
require 'cgi'
require 'rss'
require 'erb'
require 'logger'
require RUBY_VERSION < "1.9" ? 'ftools' : 'fileutils'

SLOGGER_HOME = File.dirname(File.expand_path(__FILE__))
ENV['SLOGGER_HOME'] = SLOGGER_HOME

require SLOGGER_HOME + '/lib/sociallogger.rb'
require SLOGGER_HOME + '/lib/configtools.rb'
require SLOGGER_HOME + '/lib/json.rb'

class String
  def markdownify
    contents = ''
    IO.popen('"$SLOGGER_HOME/lib/html2text"', "r+") do |io|

      Thread.new { self.each_line { |line|
        io << line
      }; io.close_write }

      io.each_line do |line|
        contents << line
      end
    end
    contents
  end

  def e_sh
    self.to_s.gsub(/(?=[^a-zA-Z0-9_.\/\-\x7F-\xFF\n])/, '\\').gsub(/\n/, "'\n'").sub(/^$/, "''")
  end

end

class Slogger

  attr_accessor :config, :dayonepath, :plugins
  def initialize

    cfg = ConfigTools.new
    @log = Logger.new(STDERR)
    @template = self.template
    @plugins = []

    if cfg.config_exists?
      @config = cfg.load_config
      if @config.nil?
        raise "Config should not be nil"
        Process.exit(-1)
      end
    else
      @config = cfg.load_config
      self.read_plugins
      cfg.dump_config
      Process.exit(0)
    end
  end

  def storage_path
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
      raise "Path not specified or doesn't exist: #{@config['storage']}"
      Process.exit(-1)
    end
  end

  def read_plugins
    Dir[SLOGGER_HOME + "/plugins/*.rb"].each do |file|
      require file
    end
  end

  def run_plugins
    p @plugins
    @plugins.each do |plugin|
      eval(plugin['class']).new.do_log
      # eval(plugin['class']).new.do_log
    end
  end

  def register_plugin(plugin)
    @plugins.push plugin
  end

  def template
    ERB.new <<-XMLTEMPLATE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Creation Date</key>
  <date><%= datestamp %></date>
  <key>Entry Text</key>
  <string><%= entry %></string>
  <key>Starred</key>
  <<%= starred %>/>
  <key>UUID</key>
  <string><%= uuid %></string>
</dict>
</plist>
XMLTEMPLATE
  end
end

require SLOGGER_HOME + '/lib/redirect.rb'
require SLOGGER_HOME + '/lib/dayone.rb'
$slog = Slogger.new
$slog.dayonepath = $slog.storage_path
if ARGV.length > 0
  DayOne.new.store_single_photo(ARGV[0],{},true)
else
  $slog.run_plugins
end

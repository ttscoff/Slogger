#!/usr/bin/ruby
# encoding: utf-8

if ARGV.nil? || ARGV.length < 1
  raise "Slogger Image requires that you feed it a filename."
  Process.exit(-1)
end
require 'time'
require File.dirname(__FILE__) + '/lib/sociallogger.rb'
require File.dirname(__FILE__) + '/lib/configtools.rb'

file = ARGV[0]

cfg = ConfigTools.new
log = Logger.new(STDERR)
if cfg.config_exists?
  config = cfg.load_config
  if config.nil?
    raise "Config should not be nil"
    Process.exit(-1)
  end

  storage = config['storage'] || 'icloud'

  sl = DayOne.new({ 'storage' => storage })
  sl.debug = false

  options = {}
  ## uncomment below if you want the image to be inserted at
  ## the date it was created rather than the current date.
  # options['datestamp'] = Time.parse(%x{mdls -raw -name kMDItemContentCreationDate "#{File.expand_path(file)}"}).utc.iso8601
  sl.store_single_photo(file,options,true)
end

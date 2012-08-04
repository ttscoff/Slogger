#!/usr/bin/ruby
# encoding: utf-8

require 'time'
require File.dirname(__FILE__)+'/lib/sociallogger.rb'

file = ARGV[0]

sl = DayOne.new
sl.debug = false

options = {}
## uncomment below if you want the image to be inserted at
## the date it was created rather than the current date.
# options['datestamp'] = Time.parse(%x{mdls -raw -name kMDItemContentCreationDate "#{File.expand_path(file)}"}).utc.iso8601
sl.store_single_photo(file,options)

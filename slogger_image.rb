#!/usr/bin/ruby
# encoding: utf-8

if ARGV.nil? || ARGV.length < 1
  raise "Slogger Image requires that you feed it a filename."
  Process.exit(-1)
end

slogger = File.dirname(__FILE__) + '/slogger'
%x{"#{slogger}" "#{ARGV[0]}"}

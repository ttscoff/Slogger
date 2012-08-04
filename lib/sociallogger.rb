class SocialLogger
  require 'open-uri'
  require 'net/http'
  require 'net/https'
  require 'time'
  require 'cgi'
  require 'rss'
  require 'erb'
  require 'logger'
  require 'fileutils'
  root = File.dirname(__FILE__)+'/'
  require root + 'create.rb'
  require root + 'rsslogger.rb'
  require root + 'twitterlogger.rb'
  require root + 'lastfmlogger.rb'
  require root + 'redirect.rb'
  def initialize(options = {})
    @debug = options['debug'] || false
    @config = options['config'] || {}
  end
  attr_accessor :debug, :config
end

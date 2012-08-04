#!/usr/bin/env ruby

require 'yaml'
require File.dirname(__FILE__)+'/lib/sociallogger.rb'
ENV['SLOGGER_HOME'] = File.dirname(File.expand_path(__FILE__))
$config_file = File.expand_path(ENV['SLOGGER_HOME']+'/slogger_config')

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
end

class ConfigTools
	def load_config
	  File.open($config_file) { |yf| YAML::load(yf) }
	end

	def dump_config (config)
	  File.open($config_file, 'w') { |yf| YAML::dump(config, yf) }
	end

	def config_exists?
		if !File.exists?($config_file)
			dump_config( {
				'lastfm_user' => '',
				'rss_feeds' => [],
				'markdownify_rss_posts' => false,
				'star_rss_posts' => false,
				'twitter_users' => [],
				'save_images' => true,
				'droplr_domain' => 'd.pr',
				'gist_user' => '',
				'rss_tags' => '@social @blogging',
				'lastfm_tags' => '@social @music',
				'twitter_tags' => '@social @twitter',
				'gist_tags' => '@social @coding'
			} )
			puts "Please update the configuration file at #{$config_file}."
			Process.exit(-1)
		end
		return true
	end
end

cfg = ConfigTools.new
log = Logger.new(STDERR)
if cfg.config_exists?
	config = cfg.load_config
	if config.nil?
		raise "Config should not be nil"
		Process.exit(-1)
	end
	if config['lastfm_user']
		log.info("Loading last.fm logger for user #{config['lastfm_user']}")
		options = {}
		options['user'] = config['lastfm_user']
		options['tags'] = config['lastfm_tags'] || ''
		LastFMLogger.new(options).log_lastfm
	end
	if config['rss_feeds']
		log.info("Loading RSS logger for feeds #{config['rss_feeds'].join(", ")}")
		options = {}
		options['feeds'] = config['rss_feeds']
		options['markdownify'] = config['markdownify_rss_posts'] || false
		options['starred'] = config['star_rss_posts'] || false
		options['tags'] = config['rss_tags'] || ''
		RSSLogger.new(options).log_rss
	end
	if config['twitter_users']
		log.info("Loading Twitter logger for user(s) #{config['twitter_users'].join(', ')}")
		options = {}
		options['twitter_users'] = config['twitter_users']
		options['tags'] = config['twitter_tags'] || ''
		TwitterLogger.new(options).log_tweets
	end
	if config['gist_user']
		require ENV['SLOGGER_HOME'] + '/lib/gistlogger.rb'
		require ENV['SLOGGER_HOME'] + '/lib/json.rb'
		log.info("Loading gist logger for user #{config['gist_user']}")
		options = {}
		options['user'] = config['gist_user']
		options['tags'] = config['gist_tags'] || ''
		GistLogger.new(options).log_gists
	end
end

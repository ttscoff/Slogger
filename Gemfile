source 'https://rubygems.org'

def plugin(name)
  gemname = "sloggerplugin-#{name}"
  path = "../#{gemname}"
  gem gemname, path: path
end

gem 'feed-normalizer'
gem 'twitter', '~> 5.3.0'
gem 'twitter_oauth'
gem 'json'
gem 'instagram'
gem 'sinatra'

gem 'nokogiri'
gem 'digest' # required for feedafever
gem 'sqlite3' # required for feedafever
gem 'rmagick', '2.13.2' # required for lastfmcovers
gem 'multimap' # required for olivetree
gem 'pry'

plugin "blogger"


group :test do
  gem 'rake'
  gem 'rspec'
  gem 'vcr'
  gem 'webmock'
end


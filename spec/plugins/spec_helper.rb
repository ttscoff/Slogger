$:.unshift File.join(File.dirname(__FILE__))
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'plugins')
$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'plugins_disabled')

require 'mock_slogger'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = File.join(File.dirname(__FILE__), 'fixtures')
  c.hook_into :webmock
end

RSpec.configure do |config|
  config.color_enabled = true
end


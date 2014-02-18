$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'plugins_disabled')

require 'rspec/mocks/standalone'
$slog = double.as_null_object

RSpec.configure do |config|
  config.color_enabled = true
end

class Slogger
  def initialize
    RSpec::Mocks::setup(self)
    @config = {}
    @log = double.as_null_object
  end
end


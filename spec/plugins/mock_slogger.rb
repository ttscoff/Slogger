class Slogger
  RSpec::Mocks::setup(self)
  $slog = double.as_null_object

  attr_accessor :config, :log, :timespan

  def initialize
    RSpec::Mocks::setup(self)
    @config = {}
    @log = double.as_null_object
  end
end

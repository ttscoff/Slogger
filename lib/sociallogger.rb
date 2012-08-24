class SocialLogger
  def initialize(options = {})
    @debug = options['debug'] || false
    @config = options['config'] || {}
  end
  attr_accessor :debug, :config
end

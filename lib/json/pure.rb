require ENV['SLOGGER_HOME'] + '/lib/json/common'
require ENV['SLOGGER_HOME'] + '/lib/json/pure/parser'
require ENV['SLOGGER_HOME'] + '/lib/json/pure/generator'

module JSON
  # This module holds all the modules/classes that implement JSON's
  # functionality in pure ruby.
  module Pure
    $DEBUG and warn "Using Pure library for JSON."
    JSON.parser = Parser
    JSON.generator = Generator
  end

  JSON_LOADED = true unless defined?(::JSON::JSON_LOADED)
end

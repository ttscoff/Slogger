require ENV['SLOGGER_HOME'] + '/lib/json/common'

module JSON
  # This module holds all the modules/classes that implement JSON's
  # functionality as C extensions.
  module Ext
    require ENV['SLOGGER_HOME'] + '/lib/json/ext/parser'
    require ENV['SLOGGER_HOME'] + '/lib/json/ext/generator'
    $DEBUG and warn "Using Ext extension for JSON."
    JSON.parser = Parser
    JSON.generator = Generator
  end

  JSON_LOADED = true unless defined?(::JSON::JSON_LOADED)
end

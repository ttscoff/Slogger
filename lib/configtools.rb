require 'yaml'

class ConfigTools
  def initialize(options = {})
    @config_file = options['config_file'] || File.expand_path(File.dirname(__FILE__)+'/../slogger_config')
  end
  attr_accessor :config_file

  def load_config
    File.open(@config_file, 'r') { |yf| JSON.parse(yf) }
  end

  def dump_config (config)
    File.open(@config_file, 'w') { |yf| yf.puts(config.to_json) }
  end

  def default_config
    config = {
      'storage' => 'icloud'
    }
    config
  end

  def config_exists?
    if !File.exists?(@config_file)
      dump_config( default_config )
      return false
      # puts "Please update the configuration file at #{@config_file}."
      # Process.exit(-1)
    else
      return true
    end
  end
end

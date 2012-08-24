require 'yaml'

class ConfigTools
  def initialize(options = {})
    @config_file = options['config_file'] || File.expand_path(File.dirname(__FILE__)+'/../slogger_config')
  end
  attr_accessor :config_file

  def load_config
    File.open(@config_file) { |yf| YAML::load(yf) }
  end

  def dump_config (config)
    File.open(@config_file, 'w') { |yf| YAML::dump(config, yf) }
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
      puts "Please update the configuration file at #{@config_file} then run Slogger again."
      Process.exit(-1)
      # return false
    else
      return true
    end
  end
end

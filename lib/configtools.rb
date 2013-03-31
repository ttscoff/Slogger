require 'yaml'

class ConfigTools
  attr_accessor :config_file
  def initialize(options)
    YAML::ENGINE.yamler = 'syck' if defined?(YAML::ENGINE) && RUBY_VERSION < "2.0.0"
    @config_file = options['config_file']
  end

  def load_config
    File.open(@config_file) { |yf| YAML::load(yf) }
  end

  def dump_config (config)
    File.open(@config_file, 'w') { |yf| YAML::dump(config, yf) }
  end

  def default_config
    config = {
      'storage' => 'icloud',
      'image_filename_is_title' => true,
      'date_format' => '%F',
      'time_format' => '%R'
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

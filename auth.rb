#!/usr/bin/env ruby

require 'rubygems'
require 'oauth2'
require 'optparse'
require 'fileutils'
require 'logger'
require 'socket'
require 'webrick'

SLOGGER_HOME = File.dirname(File.expand_path(__FILE__))

require SLOGGER_HOME + '/lib/configtools'

$log = Logger.new(STDERR)

class Slogger
end

class Auth
  def initialize
    cfg = ConfigTools.new({'config_file' => $options[:config_file]})
    @plugins = []
    if cfg.config_exists?
      @config = cfg.load_config
      if @config.nil?
        raise "Config should not be nil"
        Process.exit(-1)
      end
    end
  end

  def register_plugin(plugin)
    if plugin.key?('auth')
      @plugins.push plugin
    end
  end

  def auth_plugins
    plugin_dir = $options[:develop] ? "/plugins_develop/*.rb" : "/plugins/*.rb"
    Dir[SLOGGER_HOME + plugin_dir].each do |file|
      if $options[:onlyrun]
        $options[:onlyrun].each { |plugin_frag|
          if File.basename(file) =~ /^#{plugin_frag}/i
            require file
          end
        }
      else
        require file
      end
    end

    @plugins.each do |plugin|
      if plugin['auth']['type'] == :oauth2
        oauth2_plugin(plugin)
      end

      # TODO: work out how to update the config...
      # plugin['auth'].each do |k,v|
      #   if @config[_namespace][k].nil?
      #     new_options = true
      #     @config[_namespace][k] ||= v
      #   end
      #   @config[_namespace][_namespace+"_last_run"] = Time.now.strftime('%c')
      # end
      # # credit to Hilton Lipschitz (@hiltmon)
      # updated_config = eval(plugin['class']).new.do_log
      # if updated_config && updated_config.class.to_s == 'Hash'
      #   updated_config.each { |k,v|
      #     @config[_namespace][k] = v
      #   }
      # end
    end
    # ConfigTools.new({'config_file' => $options[:config_file]}).dump_config(@config)
    
  end

  def oauth2_plugin(plugin)
    auth = plugin['auth']

    client = OAuth2::Client.new(auth['id'], auth['secret'], {:site => auth['site'], :authorize_url => auth['authorize'], :token_url => auth['token']})

    server = TCPServer.open 8080
    server.listen(1)

    system("open", client.auth_code.authorize_url(:redirect_uri => 'http://localhost:8080/oauth2/callback'))
    # => "https://example.org/oauth/authorization?response_type=code&client_id=client_id&redirect_uri=http://localhost:8080/oauth2/callback"

    req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
    req.parse(server.accept)
    code = req.query['code']
    
    access_token_obj = client.auth_code.get_token(code, {'client_id' => auth['id'], 'client_secret' => auth['secret'], 'redirect_uri' => 'http://localhost:8080/oauth2/callback' })

    puts "OAuth2 completed for #{plugin['class']}"
    puts "Token is: #{access_token_obj.token}"
    puts "Refresh token is: #{access_token_obj.refresh_token}"
  end
  
end

$options = {}
optparse = OptionParser.new do|opts|
  opts.banner = "Usage: " + __FILE__ + " [-d]"
  $options[:config_file] = SLOGGER_HOME + '/slogger_config'
  opts.on( '-c', '--config FILE', 'Specify configuration file to use') do |file|
    file = File.expand_path(file)
    $options[:config_file] = file
  end
  $options[:develop] = false
  opts.on( '-d','--develop', 'Develop mode' ) do
    $options[:develop] = true
  end
  $options[:onlyrun] = false
  opts.on( '-o','--onlyrun NAME[,NAME2...]','Only run plugins matching items in comma-delimited string') do |plugin_string|
    $options[:onlyrun] = plugin_string.split(/,/).map {|frag| frag.strip }
  end
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!

$slog = Auth.new
$slog.auth_plugins


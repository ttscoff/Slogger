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

  def config_exists?
    if !File.exists?(@config_file)
      dump_config( {
        'lastfm_user' => '',
        'rss_feeds' => [],
        'markdownify_rss_posts' => false,
        'star_rss_posts' => false,
        'twitter_users' => [],
        'save_images' => true,
        'droplr_domain' => 'd.pr',
        'gist_user' => '',
        'rss_tags' => '@social @blogging',
        'lastfm_tags' => '@social @music',
        'twitter_tags' => '@social @twitter',
        'gist_tags' => '@social @coding',
        'storage' => 'icloud'
      } )
      puts "Please update the configuration file at #{@config_file}."
      Process.exit(-1)
    end
    return true
  end
end

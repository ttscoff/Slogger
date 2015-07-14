require 'fileutils'

namespace :plugin do
  desc 'Installs a plugin'
  task :install, :name do |t, args|
    name = args[:name]
    ensure_plugin_directory_is_created
    github_repo = "git@github.com:sloggerplugins/#{name}.git"
    system("git clone --depth=1 #{github_repo} #{plugin_directory}/#{name}")
    FileUtils.ln_s(
      File.expand_path("#{plugin_directory}/#{name}"),
      File.expand_path("plugins/")
    )
  end

  desc 'Disable a currently installed plugin'
  task :disable, :name do |t, args|
    name = args[:name]

    if Dir.exists?(enabled_plugin(name))
      FileUtils.move(enabled_plugin(name), disabled_plugin(name))
    else
      puts "There is no currently-enabled plugin named #{name}."
    end
  end

  desc 'Enabled a currently disabled plugin'
  task :enable, :name do |t, args|
    name = args[:name]

    if Dir.exists?(disabled_plugin(name))
      FileUtils.move(disabled_plugin(name), enabled_plugin(name))
    else
      puts "There is no currently-disabled plugin named #{name}."
    end
  end

  def ensure_plugin_directory_is_created
    unless Dir.exists?(plugin_directory)
      FileUtils.mkdir(plugin_directory)
    end
  end

  def plugin_directory
    "../slogger_plugins"
  end

  def disabled_plugin(name)
    "plugins_disabled/#{name}"
  end

  def enabled_plugin(name)
    "plugins/#{name}"
  end
end

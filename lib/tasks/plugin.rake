namespace :plugin do
  desc 'Installs a plugin'
  task :install, :name do |t, args|
    name = args[:name]
    github_repo = "git@github.com:sloggerplugins/#{name}.git"
    system("git submodule add #{github_repo} plugins/#{name}")
  end
end

namespace :plugin do
  desc 'Installs a plugin'
  task :install, :name do |t, args|
    name = args[:name]
    github_repo = "git@github.com:sloggerplugins/#{name}.git"
    system("git clone --depth=1 #{github_repo} plugins/#{name}")
  end
end

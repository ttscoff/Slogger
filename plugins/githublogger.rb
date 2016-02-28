=begin
Plugin: Github Logger
Version: 1.1
Description: Logs daily Github activity for the specified user
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  github_user: githubuser
  github_tags: "#social #coding"
Notes:

=end
# NOTE: Requires json gem
config = {
  'description' => ['Logs daily Github activity for the specified user','github_user should be your Github username'],
  'github_user' => '',
  'github_tags' => '#social #coding',
}
$slog.register_plugin({ 'class' => 'GithubLogger', 'config' => config })

class GithubLogger < Slogger

  def do_log
    if @config.key?(self.class.name)
        config = @config[self.class.name]
        if !config.key?('github_user') || config['github_user'] == ''
          @log.warn("Github user has not been configured or is invalid, please edit your slogger_config file.")
          return
        end
    else
      @log.warn("Github user has not been configured, please edit your slogger_config file.")
      return
    end
    @log.info("Logging Github activity for #{config['github_user']}")
    begin
      url = URI.parse "https://api.github.com/users/#{config['github_user'].strip}/events"

      http = Net::HTTP.new url.host, url.port
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.use_ssl = true

      res = nil

      http.start do |agent|
        res = agent.get(url.path).read_body
      end
    rescue Exception => e
      @log.error("ERROR retrieving Github url: #{url}")
      # p e
    end

    return false if res.nil?
    json = JSON.parse(res)

    output = ""

    json.each {|action|
      date = Time.parse(action['created_at'])
      if date > @timespan
        case action['type']
          when "PushEvent"
            if !action["repo"]
              action['repo'] = {"name" => "unknown repo"}
            end
            output += "* Pushed to branch *#{action['payload']['ref'].gsub(/refs\/heads\//,'')}* of [#{action['repo']['name']}](#{action['url']})\n"
            action['payload']['commits'].each do |commits|
              output += "    * #{commits["message"]}\n"
            end
          when "GistEvent"
            output += "* Created gist [#{action['payload']['name']}](#{action['payload']['url']})\n"
            output += "    * #{action['payload']['desc'].gsub(/\n/," ")}\n" unless action['payload']['desc'].nil?
          when "WatchEvent"
            if action['payload']['action'] == "started"
              output += "* Started watching [#{action['repo']['owner']}/#{action['repo']['name']}](#{action['repo']['url']})\n"
              output += "    * #{action['repo']['description'].gsub(/\n/," ")}\n" unless action['repo']['description'].nil?
            end
        end
      else
        break
      end
    }

    return false if output.strip == ""
    entry = "## Github activity for #{Time.now.strftime(@date_format)}:\n\n#{output}\n(#{config['github_tags']})"
    DayOne.new.to_dayone({ 'content' => entry })
  end

end

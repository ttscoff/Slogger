=begin
Plugin: Github Commit Logger
Description: Logs daily Github commit activity(public and private) for the specified user.
Author: [David Barry](https://github.com/DavidBarry) 
Configuration:
  github_user: githubuser
  github_token: githubtoken
  github_tags: "#social #coding"
Notes:
This requires getting an OAuth token from github to get access to your private commit activity.
You can get a token by running this command in the terminal:
curl -u 'username' -d '{"scopes":["repo"],"note":"Help example"}' https://api.github.com/authorizations
where username is your github username.
=end
# NOTE: Requires json gem
config = {
  'description' => ['Logs daily Github commit activity(public and private) for the specified user.',
                    'github_user should be your Github username',
                    'Instructions to get Github token <https://help.github.com/articles/creating-an-oauth-token-for-command-line-use>'],
  'github_user' => '',
  'github_token' => '',
  'github_tags' => '#social #coding',
}
$slog.register_plugin({ 'class' => 'GithubCommitLogger', 'config' => config })

class GithubCommitLogger < Slogger

  def do_log
    if @config.key?(self.class.name)
        config = @config[self.class.name]
        if !config.key?('github_user') || config['github_user'] == ''
          @log.warn("Github user has not been configured or is invalid, please edit your slogger_config file.")
          return
        end

        if !config.key?('github_token') || config['github_token'] == ''
          @log.warn("Github token has not been configured, please edit your slogger_config file.")
          return
        end
    else
      @log.warn("Github Commit Logger has not been configured, please edit your slogger_config file.")
      return
    end
    @log.info("Logging Github activity for #{config['github_user']}")
    begin
      url = URI.parse "https://api.github.com/users/#{config['github_user']}/events?access_token=#{config['github_token']}"

      res = Net::HTTP.start(url.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        http.get url.request_uri, 'User-Agent' => 'Slogger'
      end

    rescue Exception => e
      @log.error("ERROR retrieving Github url: #{url}")
    end

    return false if res.nil?
    json = JSON.parse(res.body)

    output = ""

    json.each {|action|
      date = Time.parse(action['created_at'])
      if date > @timespan
        case action['type']
          when "PushEvent"
            if !action['repo']
              action['repo'] = {"name" => "unknown repository"}
            end
            output += "* Pushed to branch *#{action['payload']['ref'].gsub(/refs\/heads\//,'')}* of [#{action['repo']['name']}](#{action['url']})\n"
            action['payload']['commits'].each do |commit|
              output += "    * #{commit['message'].gsub(/\n+/," ")}\n" 
            end
        end
      else
        break
      end
    }

    return false if output.strip == ""
    entry = "Github activity for #{Time.now.strftime(@date_format)}:\n\n#{output}\n#{config['github_tags']}"
    DayOne.new.to_dayone({ 'content' => entry })
  end

end

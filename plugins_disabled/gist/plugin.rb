=begin
Plugin: Gist Logger
Description: Logs daily Gists for the specified user
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  gist_user: githubuser
  gist_tags: "#social #coding"
Notes:

=end
# NOTE: Requires json gem
config = {
  'description' => ['Logs daily Gists for the specified user','gist_user should be your Github username'],
  'gist_user' => '',
  'gist_tags' => '#social #coding',
}
$slog.register_plugin({ 'class' => 'GistLogger', 'config' => config })

class GistLogger < Slogger

  def do_log
    if @config.key?(self.class.name)
        config = @config[self.class.name]
        if !config.key?('gist_user') || config['gist_user'] == ''
          @log.warn("RSS feeds have not been configured or a feed is invalid, please edit your slogger_config file.")
          return
        end
    else
      @log.warn("Gist user has not been configured, please edit your slogger_config file.")
      return
    end
    @log.info("Logging gists for #{config['gist_user']}")
    begin
      url = URI.parse "https://api.github.com/users/#{config['gist_user']}/gists"

      http = Net::HTTP.new url.host, url.port
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.use_ssl = true

      res = nil

      http.start do |agent|
        res = agent.get(url.path).read_body
      end
    rescue Exception => e
      raise "ERROR retrieving Gist url: #{url}"
      p e
    end
    # begin
    #   gist_url = URI.parse("https://api.github.com/users/#{@user}/gists")
    #   res = Net::HTTPS.get_response(gist_url).body

    return false if res.nil?
    json = JSON.parse(res)

    output = ""

    json.each {|gist|
      date = Time.parse(gist['created_at'])
      if date > @timespan
        output += "* Created [Gist ##{gist['id']}](#{gist["html_url"]})\n"
        output += "    * #{gist["description"]}\n" unless gist["description"].nil?
      else
        break
      end
    }

    return false if output.strip == ""
    entry = "## Gists for #{Time.now.strftime(@date_format)}:\n\n#{output}\n#{config['gist_tags']}"
    DayOne.new.to_dayone({ 'content' => entry })
  end

end

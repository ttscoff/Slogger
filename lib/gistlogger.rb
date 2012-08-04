# NOTE: Requires json gem
class GistLogger < SocialLogger
  def initialize(options = {})
    if !options['user'].empty?
      options.each_pair do |att_name, att_val|
        instance_variable_set("@#{att_name}", att_val)
      end
    else
      raise "No Gist user configured"
      return false
    end

    @tags ||= ''
    @tags = "\n\n#{@tags}\n" unless @tags == ''
    @storage ||= 'icloud'
  end
  attr_accessor :user

  def e_sh(str)
    str.to_s.gsub(/(?=[^a-zA-Z0-9_.\/\-\x7F-\xFF\n])/, '\\').gsub(/\n/, "'\n'").sub(/^$/, "''")
  end

  def log_gists

    begin
      url = URI.parse "https://api.github.com/users/#{@user}/gists"

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
    now = Time.now()
    yesterday = now - (60 * 60 * 24)

    output = ""

    json.each {|gist|
      date = Time.parse(gist['created_at'])
      if date > yesterday
        output += "* Created [Gist ##{gist['id']}](#{gist["html_url"]})\n"
        output += "    * #{gist["description"]}\n"
      else
        break
      end
    }

    return false if output.strip == ""
    entry = "## Gists for #{Time.now.strftime("%m-%d-%Y")}:\n\n#{output}#{@tags}"
    DayOne.new({ 'storage' => @storage }).to_dayone({ 'content' => entry })
  end

end

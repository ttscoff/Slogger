=begin
Plugin: Gaug.es Logger
Version: 1.1
Description: Logs daily traffic status from http://get.gaug.es/
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  gauges_token: XXXXXXXXXXXXXXXX
  gauges_tags: "#social #sitestats"
Notes:
  This plugin requires an API token to run. Run slogger -o "gauges" to create the
  configuration section for it. Then log into your Guag.es account and go to:
  <https://secure.gaug.es/dashboard#/account/clients> and create a new client.
  Copy the key for that client and set 'gauges_token:' to it in your slogger_config.
=end
# NOTE: Requires json gem
config = {
  'description' => ['Logs daily traffic status from http://get.gaug.es/','Create a key for gauges_token at https://secure.gaug.es/dashboard#/account/clients'],
  'gauges_token' => '',
  'gauges_tags' => '#social #sitestats',
}
$slog.register_plugin({ 'class' => 'GaugesLogger', 'config' => config })

class GaugesLogger < Slogger

  def gauges_api_call(key,type)
    type.gsub!(/https:\/\/secure.gaug.es\//,'') if type =~ /^https:/

    res = nil
    begin
      uri = URI.parse("https://secure.gaug.es/#{type}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(uri.request_uri)
      request.add_field("X-Gauges-Token", "#{key}")
      res = http.request(request)
    rescue Exception => e
      @log.error("ERROR retrieving Gaug.es information. (#{type})")
      # p e
    end

    return false if res.nil?
    JSON.parse(res.body)
  end

  def do_log
    if @config.key?(self.class.name)
        config = @config[self.class.name]
        if !config.key?('gauges_token') || config['gauges_token'] == ''
          @log.warn("Gaug.es key has not been configured or is invalid, please edit your slogger_config file.")
          return
        end
        key = config['gauges_token']
    else
      @log.warn("Gaug.es key has not been configured, please edit your slogger_config file.")
      return
    end
    @log.info("Logging Gaug.es stats")

    json = gauges_api_call(key,"gauges")
    return false unless json
    output = ""
    gauges = []
    json['gauges'].each {|g|
      gauge = {}
      gauge['title'] = g['title']
      gauge['today'] = {'views' => g['today']['views'], 'visits' => g['today']['people']}

      urls = g['urls']
      pages = gauges_api_call(key,urls['content'])
      referrers = gauges_api_call(key,urls['referrers'])
      gauge['top_pages'] = pages['content']
      gauge['top_referrers'] = referrers['referrers']

      gauges.push(gauge)
    }

    output = ""

    gauges.each {|gauge|
      output += "## #{gauge['title']}\n\n"
      output += "* Visits: **#{gauge['today']['visits']}**\n"
      output += "* Views: **#{gauge['today']['views']}**"

      output += "\n\n### Top content:\n\n"

      gauge['top_pages'][0..5].each {|page|
        output += "* [#{page['title']}](#{page['url']})\n"
      }

      output += "\n\n### Top referrers:\n\n"

      gauge['top_referrers'][0..5].each {|ref|
        output += "* <#{ref['url']}>\n"
      }
      output += "\n\n"
    }

    return false if output.strip == ""
    entry = "# Gaug.es report for #{Time.now.strftime(@date_format)}\n\n#{output}\n#{config['gauges_tags']}"
    DayOne.new.to_dayone({ 'content' => entry })
  end

end

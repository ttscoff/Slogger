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

    date = @timespan + (60 * 60 * 24)

    json = gauges_api_call(key,"gauges")
    return false unless json
    gauges = []

    while date.strftime("%Y%m%d") <= Time.now.strftime("%Y%m%d")
      json['gauges'].each {|g|
        gauge = {}
        gauge['title'] = g['title']
        gauge['date'] = date
        urls = g['urls']

        traffic = gauges_api_call(key,urls['traffic']+"?date=#{date.strftime("%Y-%m-%d")}")

        traffic['traffic'].each { |t|
          if t['date'] == date.strftime("%Y-%m-%d")
            gauge['today'] = {'views' => t['views'], 'visits' => t['people']}
          end
        }

        pages = gauges_api_call(key,urls['content']+"?date=#{date.strftime("%Y-%m-%d")}")
        referrers = gauges_api_call(key,urls['referrers']+"?date=#{date.strftime("%Y-%m-%d")}")
        gauge['top_pages'] = pages['content'][0..5]
        gauge['top_referrers'] = referrers['referrers'][0..5]

        gauges.push(gauge)
      }
      date = date + (60 * 60 * 24)
    end

    gauges.each {|gauge|
      output = ""
      # p date.strftime(@date_format)
      # p gauge['title']
      # p gauge['today']
      output += "* Visits: **#{gauge['today']['visits']}**\n"
      output += "* Views: **#{gauge['today']['views']}**"

      output += "\n\n### Top content:\n\n"

      gauge['top_pages'].each {|page|
        output += "* [#{page['title']}](#{page['url']}) (#{page['views']})\n"
      }

      output += "\n\n### Top referrers:\n\n"

      gauge['top_referrers'].each {|ref|
        output += "* <#{ref['url']}> (#{ref['views']})\n"
      }
      output += "\n\n"

      return false if output.strip == ""
      entry = "# Gaug.es report for #{gauge['title']} on #{gauge['date'].strftime(@date_format)}\n\n#{output}\n#{config['gauges_tags']}"
      DayOne.new.to_dayone({ 'content' => entry, 'datestamp' => gauge['date'].utc.iso8601 })
    }
  end

end

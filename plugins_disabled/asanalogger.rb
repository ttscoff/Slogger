=begin
Plugin: Asana Logger
Description: Logs daily Asana activity
Author: [Tom Torsney-Weir](http://www.tomtorsneyweir.com)
Configuration:
  asana_api_key: you can get this from your profile on asana
Notes:
  - asana_api_key is a string with your personal Asana api key
=end

config = { # description and a primary key (username, url, etc.) required
  'description' => ['Logs daily Asana activity',
                    'asana_api_key is a string with your personal Asana API key.',
                    'This can be obtained from your profile screen in Asana.'],
  'asana_api_key' => '',
  'asana_star_posts' => true,
  'asana_tags' => '#tasks'
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'AsanaLogger', 'config' => config })

require "json"
require "net/https"

class AsanaLogger < Slogger
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('asana_api_key') || config['asana_api_key'] == []
        @log.warn("AsanaLogger has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        api_key = config['asana_api_key']
      end
    else
      @log.warn("AsanaLogger has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging AsanaLogger posts")

    asana_tags = config['asana_tags'] || ''
    asana_tags = "\n\n#{asana_tags}\n" unless asana_tags == ''

    # Perform necessary functions to retrieve posts
    content = ""
    get_workspaces(api_key).each do |ws_info|
      ws_id = ws_info['id']
      ws_name = ws_info['name']
      @log.info("Getting tasks for #{ws_name}")
      tasks = asana(api_key, "/workspaces/#{ws_id}/tasks?include_archived=true&assignee=me")['data']
      finished_tasks = tasks.map {|t| asana(api_key, "/tasks/#{t['id']}")['data']}
      finished_tasks.select! {|t| t['completed'] and Time.parse(t['completed_at']) > @timespan}
      unless finished_tasks.empty?
        content += "### Tasks finished today:\n\n"
        finished_tasks.each do |t|
          content += "* #{format_task(t)}\n"
        end
        content += "\n"
      end
      added_tasks = tasks.map {|t| asana(api_key, "/tasks/#{t['id']}")['data']}
      added_tasks.select! {|t| Time.parse(t['created_at']) > @timespan}
      unless added_tasks.empty?
        content += "### Tasks added today:\n\n"
        added_tasks.each do |t|
          content += "* #{format_task(t)}\n"
        end
        content += "\n"
      end
    end

    # set up day one post
    options = {}
    options['datestamp'] = Time.now.utc.iso8601
    options['starred'] = config['asana_star_posts']
    options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

    # Create a journal entry
    unless content.empty?
      sl = DayOne.new
      options['content'] = "## Asana activity\n\n#{content}#{asana_tags}"
      sl.to_dayone(options)
    end
  end

  def get_workspaces(key)
    user_info = asana(key, '/users/me')
    user_info['data']['workspaces']
  end

  def format_task(task)
    projs = task['projects'] || []
    projs.map! {|p| p['name']}
    if projs.empty?
      proj_names = ""
    else
      proj_names = " (#{projs.join(', ')})"
    end
    ws_id = task['workspace']['id']
    task_url = "https://app.asana.com/0/#{ws_id}/#{task['id']}"
    "[#{task['name']}#{proj_names}](#{task_url})"
  end

  def asana(api_key, req_url, params={})
    # set up HTTPS connection
    uri = URI.parse("https://app.asana.com/api/1.0#{req_url}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    # set up the request
    req = Net::HTTP::Get.new(uri.request_uri, params)
    req.basic_auth(api_key, '')

    # issue the request
    res = http.start { |http| http.request(req) }

    # output
    body = JSON.parse(res.body)
    if body['errors'] then
      raise "Server returned an error: #{body['errors'][0]['message']}"
    end
    body
  end
end

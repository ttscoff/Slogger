# Plugin: Todoist
# Description: Logs completed todos from Todoist
# Notes: Thanks go to Brian Stearns who inspired me to create this given his
#        `Things.rb` plugin.
# Author: [Freddie Lindsey](twitter.com/freddielindsey)

config = {
  todoist_description: [
    'Logs completed todos from Todoist'
  ],
  todoist_token: '6bdc699af159db1b1e1148af84c8ecaf79cfe659',
  todoist_tags: '#todos',
  todoist_save_hashtags: true
}

$slog.register_plugin({ 'class' => 'TodoistLogger', 'config' => config })

class TodoistLogger < Slogger
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      unless config.key?(:todoist_token)
        @log.warn(
          "\tNo API token for todoist is present in your slogger_config\n" \
          "\t\t\t\t\tPlease edit your configuration file")
        return
      end
    else
      @log.warn('<Service> has not been configured or a feed is invalid, please edit your slogger_config file.')
      return
    end
    @log.info("Logging Todoist for completed tasks")

    timespan = @timespan.strftime('%d/%m/%Y')
    output = ''

    begin
      url = URI('https://todoist.com/API/v6/get_all_completed_items')
      time_ = Time.new(@timespan.year, @timespan.month, @timespan.day)
      since = time_.strftime('%Y-%m-%dT%H:%M')
      params = {
        token: config[:todoist_token],
        limit: 50,
        since: since
      }
      url.query = URI.encode_www_form(params)

      res = Net::HTTP.get_response(url)
    rescue Exception => e
      @log.error("ERROR retrieving Todoist information: #{url}")
      return false
    end

    return false unless res.is_a?(Net::HTTPSuccess)
    json = JSON.parse(res.body)

    items = json['items']
    projects = json['projects']

    entries_by_day = split_by_day(items)
    entries = []

    entries_by_day.each do |day, items|
      entries.push(compile_entry(day, items, projects))
    end

    count = 0
    entries.each do |e|
      count += 1
      options = {}
      options['title'] = "Todos completed on #{e[:day]}"
      options['content'] = e[:content]
      options['datestamp'] = e[:datestamp].utc.iso8601 if e[:datestamp]
      sl = DayOne.new
      sl.to_dayone(options)
    end

    @log.info("Todoist logged #{count} #{count > 1 ? 'entries' : 'entry'}")
  end

  def get_project(projects, id)
    id = id.to_i
    projects.each do |k, v|
      return v if k.to_i == id
    end
  end

  def split_by_day(items)
    split = {}

    for i in items
      date = DateTime.parse(i["completed_date"])
      date = Time.new(date.year, date.month, date.day)
      split[date] = [] unless split[date]
      split[date].push(i)
    end

    return split
  end

  def compile_entry(day, completed_items, projects)
    items = {}
    datestamp = day
    completed_items.each do |item|
      project = get_project(projects, item["project_id"])["name"]
      items[project] = [] unless items[project]
      items[project].push(item)
    end

    entry = "# Todoist Log\n\n"
    entry += "### Completed Items:\n\n"

    items.each do |project, items|
      entry += "\n#### #{project}\n"
      items.each do |item|
        entry += "- #{item['content']}\n"
      end
    end

    entry += "\n\n(#{config["TodoistLogger"][:todoist_tags]})"

    entry = {
      content: entry,
      datestamp: datestamp,
      day: datestamp.strftime("%F")
    }

    return entry
  end
end

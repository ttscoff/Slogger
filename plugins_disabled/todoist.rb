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

    config['todoist_tags'] ||= ''
    tags = config['todoist_tags'] == '' ? '' : "\n\n#{config['todoist_tags']}\n"

    timespan = @timespan.strftime('%d/%m/%Y')
    output = ''
    separate_days = {
      day1: []
    }

    separate_days.each do |day|
      options = {}
      options['content'] = "Some todo!\n\nDay:\t#{day}"
      sl = DayOne.new
      sl.to_dayone(options)
    end
  end
end

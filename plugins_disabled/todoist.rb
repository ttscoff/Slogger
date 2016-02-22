# Plugin: Todoist
# Description: Logs completed todos from Todoist
# Notes: Thanks go to Brian Stearns who inspired me to create this given his
#        `Things.rb` plugin.
# Author: [Freddie Lindsey](twitter.com/freddielindsey)

config = {
  'todoist_description' => [
    'Logs completed todos from Todoist'
  ],
  'todoist_tags' => '#todos',
  'todoist_save_hashtags' => true
}

$slog.register_plugin(class: 'TodoistLogger', config: config)

class TodoistLogger < Slogger
end

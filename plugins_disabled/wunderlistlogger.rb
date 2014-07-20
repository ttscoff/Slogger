=begin
Plugin: Wunderlist Logger
Version: 0.1
Description: Logs today's new and optionally completed/overdue tasks
Notes:
  wl_email is your Wunderlist email address
  wl_password is your Wunderlist password
Author: [Joe Constant](http://joeconstant.com)
Configuration:
  wl_email: 
  wl_password: 
  wl_tags: "#tasks #wunderlist"
  wl_completed: true
  wl_overdue: false
Notes:
  Requires the following gems/versions: 
  gem 'fog-wunderlist'
  gem 'jwt', '~> 0.1.4'
  gem 'fog', '~> 1.10.0'

=end
config = {
  'wl_description' => [
    'Logs today\'s new and optionally completed/overdue tasks',
    'wl_email is your Wunderlist email address',
    'wl_password is your Wunderlist password'],
  'wl_email'       => '',
  'wl_password'    => '',
  'wl_tags'        => '#tasks #wunderlist',
  'wl_completed'   => true,
  'wl_overdue'     => false
}
$slog.register_plugin({ 'class' => 'WunderlistLogger', 'config' => config })

require 'fog/wunderlist'
require 'pp'

class WunderlistLogger < Slogger
  def do_log
    if config.key?(self.class.name)
      config = @config[self.class.name]
      if !config.key?('wl_email') || config['wl_email'].empty?
        @log.warn("Wunderlist email has not been configured, please edit your slogger_config file.")
        return
      end
      if !config.key?('wl_password') || config['wl_password'].empty?
        @log.warn("Wunderlist password has not been configured, please edit your slogger_config file.")
        return
      end
    else
      @log.warn("Wunderlist email has not been configured, please edit your slogger_config file.")
      return
    end

    sl = DayOne.new
    config['wl_tags'] ||= ''
    tags = "\n\n#{config['wl_tags']}\n" unless config['wl_tags'] == ''
    today = @timespan.to_i

    @log.info("Getting Wunderlist tasks for #{config['wl_email']}")
    if config['wl_completed']
      @log.info("completed: true")
    end
    if config['wl_overdue']
      @log.info("overdue: true")
    end
    output = ''

    begin
        service = Fog::Tasks.new :provider => 'Wunderlist',
                                 :wunderlist_username => config['wl_email'],
                                 :wunderlist_password => config['wl_password']
        
        newoutput = ''
        completeoutput = ''
        overdueoutput = ''
        service.tasks.each do |task|
            if task.created_at.to_i > today
                newoutput += "* #{task.title}\n"
            end
            if config['wl_completed']
                if task.completed_at.to_i > today
                    completeoutput += "* #{task.title}\n"
                end
            end
            if config['wl_overdue']
                if task.completed_at.nil? && !task.due_date.nil? && task.due_date.to_i < today
                    list = service.lists.find { |l| l.id == task.list_id }
                    overdueoutput += "* #{task.title} on list '#{list.title}' was due '#{task.due_date}'\n"
                end
            end
        end
        unless newoutput == ''
            output += "## New\n#{newoutput}\n\n"
        end
        unless completeoutput == ''
            output += "## Completed\n#{completeoutput}\n\n"
        end
        unless overdueoutput == ''
            output += "## Overdue\n#{overdueoutput}\n\n"
        end

        unless output == ''
          options = {}
          options['content'] = "# Wunderlist tasks\n\n#{output}#{tags}"
          sl.to_dayone(options)
        end

    rescue Exception => e
        puts "Error getting tasks"
        p e
        return ''
    end
  end
end
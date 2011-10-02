#!/usr/bin/env ruby
# A daemon wrapper around the Rake task which launches all of the Resque workers.
#   resque_workers.rb start
#   resque_workers.rb stop
# When developing and debugging, run it in the foreground, not as a daemon:
#   resque_workers.rb run
require "rubygems"
require "daemons"

pid_path = File.join(File.dirname(__FILE__), "../tmp")
log_path = File.join(File.dirname(__FILE__), "../log")
daemonize_options = {
  :dir_mode => :script, # Place the pid file relative to this script's directory.
  :dir => pid_path,
  :log_dir => log_path,
  :log_output => true
}

Daemons.run_proc("resque_workers.rb", daemonize_options) do
  require "rake"
  require "resque/tasks"

  # You specify which Resque worker to run via the QUEUE env variable.
  ENV["QUEUE"] = "*"
  Rake::Task["resque:work"].invoke # this is a blocking call.
end

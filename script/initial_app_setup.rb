#!/usr/bin/env ruby-local-exec
# A quick environment setup script to help developers get started quickly.
# This will:
# - setup bundler
# - create mysql tables & run migrations
#
# Usage:
#   initial_app_setup.rb [envrionment=development]

require "open3"
environment = ARGV[0] || "development"

# Runs the command and raises an exception if its status code is nonzero.
def stream_output(command)
  exit_status = nil
  Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
    stdout.each { |line| puts line }
    exit_status = wait_thread.value.to_i
  end
  raise %Q(The command "#{command}" failed.) unless exit_status == 0
end

`bundle check > /dev/null`
unless $?.to_i == 0
  puts "running `bundle install` (this may take a minute)"
  args = (environment == "production") ? "--without dev" : ""
  stream_output("bundle install #{args}")
end

require "bundler/setup"
require "pathological"
require "terraform/dsl"
include Terraform::DSL
require "environment.rb"

def mysql_command() @mysql_command ||= (`which mysql || which mysql5`).chomp end
def mysqladmin_command() @mysql_admin ||= (`which mysqladmin || which mysqladmin5`).chomp end
def db_exists?(db_name)
  shell("#{mysql_command} -u root #{db_name} -e 'select 1' 2> /dev/null", :silent => true) rescue false
end

dep "create mysql barkeep database" do
  met? { db_exists?("barkeep") }
  meet { shell "#{mysqladmin_command} -u root create barkeep" }
end

ensure_run_once("database migrations") { shell "script/run_migrations.rb" }

satisfy_dependencies()

# This demo user is only used in Barkeep's readonly demo mode.
puts `script/create_demo_user.rb` if defined?(ENABLE_READONLY_DEMO_MODE) && ENABLE_READONLY_DEMO_MODE

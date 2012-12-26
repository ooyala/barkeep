#!/usr/bin/env ruby
# A quick environment setup script to help developers get started quickly.
# This will:
# - bundle install the required gems
# - create mysql tables & run migrations
#
# Usage:
#   initial_app_setup.rb [environment=development]

require File.expand_path(File.join(File.dirname(__FILE__), "setup_ruby"))

require "bundler/setup"
require "pathological"
require "terraform/dsl"

include Terraform::DSL
require "environment.rb"

def mysql_command() @mysql_command ||= (`which mysql || which mysql5`).chomp end
def mysqladmin_command() @mysql_admin ||= (`which mysqladmin || which mysqladmin5`).chomp end
def db_exists?(db_name)
  mysql_command_options = "-u #{DB_USER} #{db_name} --password='#{DB_PASSWORD}' -e 'select 1'"
  shell("#{mysql_command} #{mysql_command_options} 2> /dev/null", :silent => true) rescue false
end

dep "create mysql barkeep database" do
  met? { db_exists?("barkeep") }
  meet { shell "#{mysqladmin_command} -u #{DB_USER} --password='#{DB_PASSWORD}' create barkeep" }
end

ensure_run_once("database migrations") { shell "script/run_migrations.rb" }

satisfy_dependencies()

# This demo user is only used in Barkeep's readonly demo mode.
puts `script/create_demo_user.rb` if defined?(ENABLE_READONLY_DEMO_MODE) && ENABLE_READONLY_DEMO_MODE

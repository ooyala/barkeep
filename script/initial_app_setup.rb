#!/usr/bin/env ruby-local-exec
# A quick environment setup script to help developers get started quickly.
# This will:
# - setup bundler
# - create mysql tables & run migrations
# 
# Usage:
#   initial_app_setup.rb [envrionment=development]
#
# The "development" environment adds a few extras not needed in production.

environment = ARGV[0] || "development"

`bundle check > /dev/null`
unless $? == 0
  puts "running `bundle install` (this may take a minute)"
  args = (environment == "production") ? "--without dev" : ""
  output = `bundle install #{args}`
  unless $? == 0
    puts "`bundle install` failed:"
    puts output
  end
end

require "bundler/setup"
require "pathological"
require "terraform/terraform_dsl"
require "config/environment.rb"

include TerraformDsl

def mysql_command() @mysql_command ||= (`which mysql || which mysql5`).chomp end
def mysqladmin_command() @mysql_admin ||= (`which mysqladmin || which mysqladmin5`).chomp end
def db_exists?(db_name)
  shell("#{mysql_command} -u root #{db_name} -e 'select 1' 2> /dev/null", :silent => true) rescue false
end

dep "create mysql barkeep database" do
  met? { db_exists?("barkeep") }
  meet { shell "#{mysqladmin_command} -u root create barkeep" }
end

dep "database migrations" do
  has_run_once = false
  met? { has_run_once }

  meet do
    shell "script/run_migrations.rb"
    has_run_once = true
  end
end


satisfy_dependencies()

# This demo user is only used in Barkeep's readonly demo mode.
puts `script/create_demo_user.rb` if defined?(ENABLE_READONLY_DEMO) && ENABLE_READONLY_DEMO

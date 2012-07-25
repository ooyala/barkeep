#!/usr/bin/env ruby
#
# Adds a demo user to the database. This demo user is what powers the "read only" demo mode that can
# be enabled for Barkeep. We use it for the Barkeep demo linked from getbarkeep.com.
# Most deployments do not want to enable the demo mode, and so they do not want this user.

require "bundler/setup"
require "pathological"
require "lib/script_environment"

email = "joedemo@getbarkeep.com"
unless User.first(:email => email)
  puts "Creating demo user with email #{email}"
  User.create(:name => "Joe Demo User", :email => email, :permission => "demo",
      :saved_search_time_period => User::ONE_YEAR)
end

#!/usr/bin/env ruby
# This is a quickstart script to get Barkeep running inside Vagrant of a bare system. It will:
# - ensure you have Ruby 1.9 and recommends rbenv if not.
# - install gems
# - set up vagrant
# - deploy Barkeep to vagrant
#
# The total runtime of this script will be 10-15m on a clean machine. Half of that is downloading a Vagrant
# Ubuntu image, and the other half is installing Ruby 1.9 and other Ubuntu packages in the Vagrant VM.

require File.expand_path(File.join(File.dirname(__FILE__), "setup_ruby"))

require "bundler/setup"
require "pathological"

puts "* Setting up Vagrant."
require "script/setup_vagrant.rb"

puts "* Deploying Barkeep to your Vagrant VM."
stream_output("bundle exec fez vagrant deploy 2>&1")

puts "* Barkeep is up and running inside of Vagrant. Visit http://localhost:8080"
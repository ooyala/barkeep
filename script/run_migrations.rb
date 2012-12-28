#!/usr/bin/env ruby

require "bundler/setup"
require "pathological"
require "environment.rb"

migrate_to_version = nil
if ARGV.include?("rollback")
  versions = Dir.entries("migrations").map do |filename|
    # Each migration looks like 1234_name_of_migration.rb.
    version = filename.match(/(\d+)_.+\.rb/)[1] rescue nil
  end
  versions = versions.reject(&:nil?).map(&:to_i).sort
  migrate_to_version = versions[-2]
end

command = "bundle exec sequel -m migrations/"
command += " -M #{migrate_to_version}" if migrate_to_version

puts "Migrating to version #{migrate_to_version}" if migrate_to_version

host_string = "mysql2://#{DB_USER}:'#{DB_PASSWORD}'@#{DB_HOST}/#{DB_NAME}"
puts `#{command} #{host_string}`

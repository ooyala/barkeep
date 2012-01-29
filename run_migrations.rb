#!/usr/bin/env ruby-local-exec

require "./config/environment.rb"

PROTOCOL, DB_TYPE, DB_NAME, DB_HOST = DB_LOCATION.split(":")

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

host_string = "mysql://#{DB_USER}@#{DB_HOST}/#{DB_NAME}"
puts `#{command} "#{host_string}"`

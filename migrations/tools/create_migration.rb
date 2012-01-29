#!/usr/bin/env ruby-local-exec

name = ARGV[0]
unless name
  puts "Usage: create_migration.rb name_of_migration"
  exit 1
end

name = name.sub(/\.rb$/, "")

timestamp = Time.now.strftime("%Y%m%d%H%M%S") # yyyymmddhhmmss
filename = File.join(File.dirname(__FILE__), "../") + "#{timestamp}_#{name}.rb"

File.open(filename, "w") do |file|
  file.puts <<END_CODE
require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  up do

  end

  down do

  end
end
END_CODE
end
puts filename

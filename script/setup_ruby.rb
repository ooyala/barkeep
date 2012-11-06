#!/usr/bin/env ruby
# A Ruby setup script to help developers get started quickly.
# This will:
# - ensure you are running the required version of Ruby.
# - bundle install the gems Barkeep needs.

require "open3"

def rbenv_version() File.read(File.join(File.dirname(__FILE__), "../.rbenv-version")) end

def ensure_ruby_version(expected_version)
  a = expected_version.split(".").map { |n| n.to_i }
  b = RUBY_VERSION.split(".").map { |n| n.to_i }
  return if (b <=> a) >= 0
  puts "Barkeep requires Ruby version #{expected_version} or greater. You have #{RUBY_VERSION}."
  puts "You can remedy this by installing a newer Ruby using rbenv."
  puts "See http://github.com/sstephenson/rbenv for more details:\n\n"
  commands = [
    "curl https://raw.github.com/fesplugas/rbenv-installer/master/bin/rbenv-installer | bash",
    "rbenv install #{rbenv_version}"]
  puts commands.map { |command| "    #{command}" }.join("\n")
  exit 1
end

# Runs the command and raises an exception if its status code is nonzero.
def stream_output(command)
  puts command
  exit_status = nil
  Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
    stdout.each { |line| puts line }
    stderr.each { |line| puts line }
    exit_status = wait_thread.value.to_i
  end
  raise %Q(The command "#{command}" failed.) unless exit_status == 0
end

def gem_installed?(gem) `gem list '#{gem}'`.include?(gem) end

def ensure_gem(gem)
  return if gem_installed?(gem)
  stream_output "gem install #{gem} --no-ri --no-rdoc"
end

required_ruby_version = rbenv_version.split("-").first
ensure_ruby_version(required_ruby_version)
ensure_gem("bundler")
ensure_gem("terraform")

require "terraform/dsl"
include Terraform::DSL

environment = ARGV[0] || "development"

if (`lsb_release --id`["Ubuntu"] rescue nil)
  # Before running bundle install, ensure we have the necessary native dependencies for our gems.
  ensure_packages("build-essential", "libmysqlclient-dev", "libxml2-dev", "libxslt1-dev")
end

`bundle check > /dev/null`
unless $?.to_i == 0
  puts "running `bundle install` (this may take a minute)"
  stream_output("bundle install")
end

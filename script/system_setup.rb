#!/usr/bin/env ruby
# This sets up the system software on Ubuntu needed for a deploy.

# terraform_dsl.rb gets written to disk at deploy time. It comes from the Terraform gem.
require File.expand_path(File.join(File.dirname(__FILE__), "terraform_dsl"))

include Terraform::DSL

# TODO(caleb): At some point we probably want a strict supported list of Ubuntu versions. (We can check with
# lsb_release --release)
unless (`lsb_release --id`["Ubuntu"] rescue nil)
  fail_and_exit "This setup script is intended for Ubuntu."
end

ensure_packages(
  "g++", # For installing native extensions.
  "libmysqlclient-dev", # For building the native MySQL gem.
  "python-dev", # For using ruby-python
  "libxml2-dev", "libxslt1-dev", # Nokogiri
  "redis-server", "mysql-server", "nginx")

ensure_file("config/system_setup_files/.bashrc", "#{ENV['HOME']}/.bashrc")

# NOTE(caleb): I fixed a bug with Terraform's ensure_rbenv_version here:
# https://github.com/philc/terraform/commit/b9d4ddd5db082c87adc479cdc6a158634879af9d
# I'm copy-pasting the code here for now.
# TODO(caleb): Remove ensure_rbenv_ruby_fixed after we cut a new Terraform release and update the version in
# Barkeep.
def ensure_rbenv_ruby_fixed(ruby_version)
  ensure_rbenv
  ensure_packages "curl", "build-essential", "libxslt1-dev", "libxml2-dev", "libssl-dev"

  dep "rbenv ruby: #{ruby_version}" do
    met? { `bash -lc 'which ruby'`.include?("rbenv") && `rbenv versions`.include?(ruby_version) }
    meet do
      puts "Compiling Ruby will take a few minutes."
      shell "rbenv install #{ruby_version}"
      shell "rbenv rehash"
    end
  end
end

ensure_rbenv_ruby_fixed(File.read(".rbenv-version").strip)

ensure_run_once("nginx site-enabled has correct permissions") do
  shell "sudo chgrp admin -R /etc/nginx/sites-enabled", :silent => true
  shell "sudo chmod g+w -R /etc/nginx/sites-enabled", :silent => true
end

ensure_file("config/system_setup_files/nginx_site.conf", "/etc/nginx/sites-enabled/barkeep.conf") do
  `sudo /etc/init.d/nginx restart`
end

dep "configure nginx" do
  met? { !File.exists?("/etc/nginx/sites-enabled/default") }
  meet do
    # Ensure nginx gets started on system boot. It's still using non-Upstart init scripts.
    `sudo update-rc.d nginx defaults`
    # This default site configuration is not useful.
    shell "sudo rm /etc/nginx/sites-enabled/default"
    `sudo /etc/init.d/nginx restart`
  end
end

ensure_gem("bundler")

# Compare two version strings (x.y.z -- can be any number of parts) by pairwise comparing the pieces as
# integers.
class VersionString
  include Comparable
  attr_reader :parts
  def initialize(s)
    # It's very common for $COMMAND --version to spit out "my program 1.2.3" or "v1.2.3", so we'll strip
    # leading non-digits as a simple heuristic.
    @parts = s.sub(/^\D*/, "").split(".").map(&:to_i)
  end
  def <=>(other) @parts <=> other.parts end
  def at_least(min_version_string) self >= VersionString.new(min_version_string) end
end

# Need a recent version of git.
ensure_ppa("ppa:git-core/ppa")
dep "git 1.7.6+" do
  met? { in_path?("git") && VersionString.new(`git --version`).at_least("1.7.6") }
  meet { install_package("git") }
end

# Get a more recent node than the very out-of-date one Ubuntu will install by default (this is necessary for
# compatibility with some changes to how libraries are handled).
ensure_ppa("ppa:chris-lea/node.js") # This PPA is endorsed on the node GH wiki
dep "node.js" do
  met? { in_path?("node") && VersionString.new(`node --version`).at_least("0.6.0") }
  meet { install_package("nodejs") }
end

satisfy_dependencies()

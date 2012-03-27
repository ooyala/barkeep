#!/usr/bin/env ruby
# This sets up the system software on Ubuntu needed for a deploy.

# terraform_dsl.rb gets written to disk at deploy time. It comes from the Terraform gem.
require File.expand_path(File.join(File.dirname(__FILE__), "terraform_dsl"))

include Terraform::Dsl

# TODO(caleb): At some point we probably want a strict supported list of Ubuntu versions. (We can check with
# lsb_release --release)
unless (`lsb_release --id`["Ubuntu"] rescue nil)
  fail_and_exit "This setup script is intended for Ubuntu."
end

ensure_packages(
  "g++", # For installing native extensions.
  "libmysqlclient-dev", # For building the native MySQL gem.
  "python-dev", # For using ruby-python
  "redis-server", "mysql-server", "nginx")

ensure_file("deploy/system_setup_files/.bashrc", "#{ENV['HOME']}/.bashrc")

ensure_rbenv_ruby("1.9.2-p290")

ensure_file("deploy/system_setup_files/nginx_site.conf", "/etc/nginx/sites-enabled/barkeep.conf") do
  `/etc/init.d/nginx restart`
end

dep "configure nginx" do
  met? { !File.exists?("/etc/nginx/sites-enabled/default") }
  meet do
    # Ensure nginx gets started on system boot. It's still using non-Upstart init scripts.
    `update-rc.d nginx defaults`
    # This default site configuration is not useful.
    FileUtils.rm("/etc/nginx/sites-enabled/default")
    `/etc/init.d/nginx restart`
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

# Pygments -- python library for syntax coloring
ensure_package("python-setuptools")
dep "pip" do
  met? { in_path? "pip" }
  meet { shell "easy_install pip" }
end
dep "pygments" do
  met? { in_path? "pygmentize" }
  meet { shell "pip install pygments" }
end

# Get a more recent node than the very out-of-date one Ubuntu will install by default (this is necessary for
# compatibility with some changes to how libraries are handled).
ensure_ppa("ppa:chris-lea/node.js") # This PPA is endorsed on the node GH wiki
dep "node.js" do
  met? { in_path?("node") && VersionString.new(`node --version`).at_least("0.6.0") }
  meet { install_package("nodejs") }
end

# Note that this git_ssh_private_key is not checked into the repo. It gets created at deploy time.
# TODO(philc): Set up the location of this private ssh key outside of the repo
# ensure_file("script/system_setup_files/git_ssh_private_key", "#{ENV['HOME']}/.ssh/git_ssh_private_key") do
#   # The ssh command requires that this file have very low privileges.
#   shell "chmod 0600 #{ENV['HOME']}/.ssh/git_ssh_private_key"
# end

# ensure_file("deploy/system_setup_files/ssh_config", "#{ENV['HOME']}/.ssh/config")

satisfy_dependencies()

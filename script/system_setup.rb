#!/usr/bin/env ruby
# This sets up the system software on Ubuntu needed for a deploy.

require File.expand_path(File.join(File.dirname(__FILE__), "system_setup_dsl.rb"))

include SystemSetupDsl
unless `uname`.downcase.include?("linux")
  fail_and_exit "This setup script is intended for Linux on our servers. Don't run it on your Macbook."
end

ensure_packages(
  "g++", # For installing native extensions.
  "libmysqlclient-dev", # For building the native MySQL gem.
  "redis-server", "mysql-server", "nginx")

ensure_file("script/system_setup_files/.bashrc", "#{ENV['HOME']}/.bashrc")

ensure_rbenv_ruby("1.9.2-p290")

ensure_file("script/system_setup_files/nginx_site.conf", "/etc/nginx/sites-enabled/barkeep.conf") do
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

# Note that this git_ssh_private_key is not checked into the repo. It gets created at deploy time.
# TODO(philc): Set up the location of this private ssh key outside of the repo.
# ensure_file("script/system_setup_files/git_ssh_private_key", "#{ENV['HOME']}/.ssh/git_ssh_private_key") do
#   # The ssh command requires that this file have very low privileges.
#   shell "chmod 0600 #{ENV['HOME']}/.ssh/git_ssh_private_key"
# end

ensure_file("script/system_setup_files/ssh_config", "#{ENV['HOME']}/.ssh/config")

satisfy_dependencies()
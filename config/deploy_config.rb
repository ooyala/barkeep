# This is the configuration file for Fezzik (see https://github.com/dmacdougall/fezzik), which is used for
# deploying Barkeep. Have a look at its README to understand the basic structure of this file.

require "config/barkeep_deploy_helper"

set :app, "barkeep"
set :deploy_to, "/opt/#{app}"
set :release_path, "#{deploy_to}/releases/#{Time.now.strftime("%Y%m%d%H%M")}"
set :local_path, Dir.pwd
set :user, "barkeep"
# The concurrency setting given to Foreman, which we use to generate our Upstart init scripts.
# We run the Barkeep HTTP app using Unicorn which impelments its own workers, so use only 1 web worker.
set :concurrency, "web=1,resque=4,cron=1"

Fezzik.destination :vagrant do
  set :hostname, "barkeep_vagrant"
  set :domain, "#{user}@#{hostname}"
  BarkeepDeployHelper.include_common_deploy_options
  Fezzik.env :unicorn_workers, 2
  host "#{user}@#{hostname}", :deploy_user
  host "root@#{hostname}", :root_user
end

Fezzik.destination :prod do
  set :hostname, "barkeep.sv2"
  set :domain, "#{user}@#{hostname}"
  BarkeepDeployHelper.include_common_deploy_options
  Fezzik.env :unicorn_workers, 4
  host "#{user}@#{hostname}", :deploy_user
  host "root@#{hostname}", :root_user
end

BarkeepDeployHelper.load_barkeep_credentials_file
BarkeepDeployHelper.ensure_all_options_are_present
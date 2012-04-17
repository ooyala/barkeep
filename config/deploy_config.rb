# This is the configuration file for Fezzik (https://github.com/dmacdougall/fezzik)
# Define variables here for your deployment. A full list of variables can be found here:
#     http://hitsquad.rubyforge.org/vlad/doco/variables_txt.html

set :app, "barkeep"
set :deploy_to, "/opt/ooyala/#{app}"
set :release_path, "#{deploy_to}/releases/#{Time.now.strftime("%Y%m%d%H%M")}"
set :local_path, Dir.pwd
# TODO(caleb): Set up roles, run as role-barkeep (i.e. not root)
set :user, "root"
# Concurrency setting given to foreman
set :concurrency, "web=1,resque=4,cron=1"


# When deploying, we must deploy the private credentials for the email user account we send emails from.
# We do not want to check these into the repository, and so they should be stored in a file in
# $BARKEEP_CREDENTIALS. It should be of the form:
#   Fezzik.destination :prod do
#     Fezzik.env :gmail_address, "..."
#     Fezzik.env :gmail_password, "..."
#   end
#
if ENV.has_key?("BARKEEP_CREDENTIALS") && File.exist?(ENV["BARKEEP_CREDENTIALS"])
  load ENV["BARKEEP_CREDENTIALS"]
else
  puts "Unable to locate the file $BARKEEP_CREDENTIALS. You need this to deploy. See deploy_config.rb."
  exit 1
end

common_options = {
  barkeep_port: 8081,
  db_location: "DBI:Mysql:barkeep:localhost",
  db_user: "root",
  db_password: "",
  redis_host: "localhost",
  redis_port: 6379,
  openid_providers: ["https://www.google.com/accounts/o8/ud"],
  barkeep_hostname: "barkeep",
  repos_root: "#{deploy_to}/repos"
}

def include_options(options) options.each { |key, value| Fezzik.env key, value } end

Fezzik.destination :vagrant do
  set :hostname, "barkeep_vagrant"
  set :domain, "#{user}@#{hostname}"
  include_options(common_options)
end

Fezzik.destination :prod do
  set :hostname, "barkeep.sv2"
  set :domain, "#{user}@#{hostname}"
  include_options(common_options)
end

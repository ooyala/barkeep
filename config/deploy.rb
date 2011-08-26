# This is the configuration file for fezzik.
# Define variables here as you would for Vlad the Deployer.
# A full list of variables can be found here:
#     http://hitsquad.rubyforge.org/vlad/doco/variables_txt.html

set :app, "barkeep"
set :deploy_to, "/opt/ooyala/#{app}"
set :release_path, "#{deploy_to}/releases/#{Time.now.strftime("%Y%m%d%H%M")}"
set :local_path, Dir.pwd
set :user, "root"


# When deploying, we must deploy the private credentials for the email user account we send emails from.
# We do not want to check these into the repository, and so they should be stored in a file in
# $BARKEEP_CREDENTIALS. It should be of the form:
#   destination :prod do
#     env :gmail_username, "..."
#     env :gmail_password, "..."
#   end
#
if ENV.has_key?("BARKEEP_CREDENTIALS") && File.exist?(ENV["BARKEEP_CREDENTIALS"])
  require ENV["BARKEEP_CREDENTIALS"]
else
  puts "Unable to locate the file $BARKEEP_CREDENTIALS. You need this to deploy. See deploy.rb for details."
  exit 1
end

# Each destination is a set of machines and configurations to deploy to.
# You can deploy to a destination from the command line with:
#     fez to_dev deploy
#
# :domain can be an array if you are deploying to multiple hosts.
#
# You can set environment variables that will be loaded at runtime on the server
# like this:
#     env :rack_env, "production"
# This will also generate a file on the server named config/environment.rb, which you can include
# in your code to load these variables as Ruby constants. You can create your own config/environment.rb
# file to use for development, and it will be overwritten at runtime.

destination :prod do
  set :domain, "#{user}@barkeep.sv2"
  env :db_location, "DBI:Mysql:barkeep:localhost"
  env :db_user, "root"
  env :db_password, ""
end

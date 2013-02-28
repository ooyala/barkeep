# This is the configuration file for Fezzik (see https://github.com/dmacdougall/fezzik), which is used for
# deploying Barkeep. Have a look at Fezzik's README to understand the basic flow of Fezzik deployments.
# This file specifies the common options that most Barkeep deployments share. Add your own per-host
# configuration file in config/deploy_targets to specify your specific settings like the hostname to deploy to.
# See config/deploy_targets/vagrant.rb for an example.

set :app, "barkeep"
set :deploy_to, "/opt/#{app}"
set :release_path, "#{deploy_to}/releases/#{Time.now.strftime("%Y%m%d%H%M")}"
set :local_path, Dir.pwd
set :user, "barkeep"

# This deploy helper provides some common deploy-related configuration, like common Barkeep options.
module BarkeepDeploy
  def self.common_options
    # Note that these options use the "deploy_to" and "hostname" vars, so those must have been defined prior
    # to calling this function (e.g. via set :deploy_to, "path").
    common_options = {
      barkeep_port: 8040,
      db_host: "localhost",
      db_port: 3306,
      db_name: "barkeep",
      db_user: "root",
      db_password: "",
      redis_host: "localhost",
      redis_port: 6379,
      redis_db: 0,
      redis_db_for_resque: 1,
      # This can be a comma-separated list of OPENID providers.
      openid_providers: "https://www.google.com/accounts/o8/ud",
      # This hostname is used when generating URLs to commits in emails.
      barkeep_hostname: hostname,
      repos_root: "#{deploy_to}/repos",
      unicorn_pid_file: "#{deploy_to}/unicorn.pid",
      unicorn_socket: "/tmp/barkeep-unicorn.sock",
      unicorn_workers: 4,
      resque_workers: 4,
      rack_env: "production"
    }
  end

  # Call this from within a Fezzik.destination block to include each of the common Barkeep deploy options.
  # After this has been called, you can then override any of those options by calling Fezzik.env(key, value).
  def self.include_common_deploy_options
    common_options.each { |key, value| Fezzik.env key, value }
  end

  def self.ensure_all_options_are_present
    # These usually come from the $BARKEEP_CREDENTIALS file (see "load_barkeep_credentials_file()" for more
    # info) and so are often forgotten/missing.
    required_options = [:gmail_address, :gmail_password, :cookie_session_secret]
    required_options.each do |option|
      next if Fezzik.environments[hostname][option]
      puts "You haven't defined the Fezzik env variable #{option}, which is needed for this deploy. " +
          "Add it to your configuration in config/deploy_targets/."
      exit 1
    end
  end

  # This loads an optional credentials file from the path $BARKEEP_CREDENTIALS.
  #
  # When deploying, we must provide the private credentials for the email user account we use to send emails.
  # We do not want to check these credentials into the git repository, and so by convention we're expecting
  # them to be stored in a file whose path is the $BARKEEP_CREDENTIALS env variable. The file should look
  # like this:
  #
  #   Fezzik.destination :prod do
  #     Fezzik.env :gmail_address, "..."
  #     Fezzik.env :gmail_password, "..."
  #     # This secret is used to encrypt session information into cookies.
  #     Fezzik.env :cookie_session_secret, "a long, random, and secret string."
  #   end
  #
  def self.load_barkeep_credentials_file
    if ENV.has_key?("BARKEEP_CREDENTIALS") && File.exist?(ENV["BARKEEP_CREDENTIALS"])
      load ENV["BARKEEP_CREDENTIALS"]
    else
      puts "Unable to locate the file $BARKEEP_CREDENTIALS. You need this to deploy. See deploy_helpers.rb."
      exit 1
    end
  end
end

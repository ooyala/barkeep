# This specifies options for deploying to the host "barkeep_vagrant" using Fezzik, our deployment framework.
# See config/deploy_targets/common.rb for more info and options.

Fezzik.destination :vagrant do
  set :hostname, "barkeep_vagrant"
  set :domain, hostname
  BarkeepDeploy.include_common_deploy_options
  Fezzik.env :unicorn_workers, 2
  # Replace these with your own Gmail account credentials if you want to test Barkeep's email features.
  Fezzik.env :gmail_address, "use_your_own_account@gmail.com"
  Fezzik.env :gmail_password, "password!"
   # This secret is used to encrypt session information into cookies.
  Fezzik.env :cookie_session_secret, "This should be a long, random, secret string."
  Fezzik.role :deploy_user, :user => "barkeep"
  Fezzik.role :root_user, :user => "root"
end

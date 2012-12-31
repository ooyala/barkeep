# This specifies options for deploying to the host "barkeep_vagrant" using Fezzik, our deployment framework.
# See config/deploy_targets/common.rb for more info and options.

Fezzik.destination :vagrant do
  set :hostname, "barkeep_vagrant"
  set :domain, hostname
  BarkeepDeploy.include_common_deploy_options
  Fezzik.env :unicorn_workers, 2
  # Replace these with your own email account credentials if you want to test Barkeep's email features.
  mail_user = ""
  mail_domain = ""
  Fezzik.env :pony_options, {
    :address => "smtp.gmail.com",
    :port => "587",
    :enable_starttls_auto => true,
    :user_name => "#{mail_user}@#{mail_domain}",
    :password => "",
    :authentication => :plain,
    # the HELO domain provided by the client to the server
    :domain => "localhost.localdomain"
  }
  Fezzik.env :requests_outgoing_address, "#{mail_user}+requests@#{mail_domain}"
  Fezzik.env :commits_outgoing_address,  "#{mail_user}+commits@#{mail_domain}"
  Fezzik.env :comments_outgoing_address, "#{mail_user}+comments@#{mail_domain}"
   # This secret is used to encrypt session information into cookies.
  Fezzik.env :cookie_session_secret, "This should be a long, random, secret string."
  # This "deploy_user" is the user that code will be deployed and run as.
  Fezzik.role :deploy_user, :user => "barkeep"
  # This "sudo_user" is a user who can ssh into the machine you want to deploy to, and who has passwordless
  # sudo privileges. This user is perfroms the initial system setup, which includes installing some native
  # packages.
  Fezzik.role :sudo_user, :user => "vagrant"
end

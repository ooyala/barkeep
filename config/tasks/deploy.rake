require "fileutils"
require "terraform"
require "tilt"
require "statusz"

# Run multiple commands in one big ssh invocation, for brevity and ssh efficiency.
def run_commands(*commands) run commands.join(" && ") end

STDOUT.sync = true # If deploy.rake gets run from another script, output will be buffered. Prevent that.

namespace :fezzik do
  desc "stages the project for deployment in /tmp"
  task :stage do
    puts "Staging project in /tmp/#{app}."
    staging_dir = "/tmp/#{app}/staged"
    FileUtils.rm_rf "/tmp/#{app}"
    FileUtils.mkdir_p staging_dir

    # Use rsync to preserve executability and follow symlinks.
    system("rsync -aqE #{local_path}/. #{staging_dir} --exclude tmp/ --exclude=/.git/ --exclude=log/*.log")
    # Copy over the test git metadata if the .git in that directory is a gitfile
    test_git_repo = "test/fixtures/test_git_repo"
    if File.file?("#{staging_dir}/#{test_git_repo}/.git")
      FileUtils.rm "#{staging_dir}/#{test_git_repo}/.git"
      FileUtils.mkdir "#{staging_dir}/#{test_git_repo}/.git"
      system("rsync -aqE #{local_path}/.git/modules/#{test_git_repo}/. #{staging_dir}/#{test_git_repo}/.git")
      # core.worktree makes the repo dependent on location...seems to work to remove it.
      # TODO(caleb): Revisit the whole copying-the-test-repo thing.
      config_lines = File.readlines "#{staging_dir}/#{test_git_repo}/.git/config"
      config_lines.reject! { |line| line =~ /worktree/ }
      File.open("#{staging_dir}/#{test_git_repo}/.git/config", "w") do |file|
        config_lines.each { |line| file.write(line) }
      end
    end
    Terraform.write_dsl_file("#{staging_dir}/script/")
    Rake::Task["fezzik:evaluate_conf_file_templates"].invoke
    Rake::Task["fezzik:write_statusz_file"].invoke
  end

  # When setting up a system for deploy, we fill in some conf file templates (like nginx.conf) using env vars
  # from this deploy, and then copy those conf files to the remote system.
  desc "Evaluates the templates in script/system_setup_files using Fezzik's current env vars."
  task :evaluate_conf_file_templates do
    env_settings = Fezzik.environments[hostname]
    template = Tilt::ERBTemplate.new("config/system_setup_files/nginx_site.conf.erb", 1,
        :default_encoding => "utf-8")
    nginx_conf = template.render(Object.new,
        :hostname => hostname,
        :port => env_settings[:barkeep_port])
    File.write("/tmp/#{app}/staged/config/system_setup_files/nginx_site.conf", nginx_conf)
  end

  desc "performs any necessary setup on the destination servers prior to deployment"
  remote_task :setup, :roles => :sudo_user do
    unless Fezzik.roles[:deploy_user]
      fail "Define a deploy user role in your deploy_targets file."
    end
    deploy_user = Fezzik.roles[:deploy_user][:user]
    has_user = Fezzik::Util.capture_output { run "getent passwd #{deploy_user} || true" }.size > 0
    unless has_user
      puts "Creating #{deploy_user} user."
      # Make a user which has the same authorized keys as our root user, so we can ssh in as that user.
      run_commands(
          "sudo useradd --create-home --shell /bin/bash #{deploy_user}",
          "sudo adduser #{deploy_user} --add_extra_groups admin",
          "sudo mkdir -p /home/#{deploy_user}/.ssh/",
          "sudo cp ~/.ssh/authorized_keys /home/#{deploy_user}/.ssh",
          "sudo chown -R #{deploy_user} /home/#{deploy_user}/.ssh")
      # Ensure users in the "admin" group can passwordless sudo.
      sudoers_line = "'%admin ALL=NOPASSWD:ALL'"
      run "if test -f /etc/sudoers.local; then " +
          # # NOTE(philc): We can't do a simple "echo xyz > file" using sudo, so use tee to output instead.
          "echo #{sudoers_line} | sudo tee /etc/sudoers.local; " +
          "else echo #{sudoers_line} | sudo tee /etc/sudoers; fi"
    end
    run "sudo mkdir -p #{deploy_to}/releases && sudo chown #{deploy_user} #{deploy_to} #{deploy_to}/releases"
  end

  desc "rsyncs the project from its staging location to each destination server"
  remote_task({ :push => [:stage, :setup] }, { :roles => :deploy_user }) do
    puts "Pushing to #{target_host}:#{release_path}."
    # Copy on top of previous release to optimize rsync
    rsync "-q", "--copy-dest=#{current_path}", "/tmp/#{app}/staged/", "#{target_host}:#{release_path}"
  end

  desc "symlinks the latest deployment to /deploy_path/project/current"
  remote_task :symlink, :roles => :deploy_user do
    puts "Symlinking current to #{release_path}."
    run "cd #{deploy_to} && ln -fns #{release_path} current"
    # Add a symlink to the current deploy in the deploy user's home directory, for convenience.
    run "rm ~/#{app}_current 2> /dev/null; ln -s #{current_path} ~/#{app}_current"
  end

  remote_task :initial_system_setup, :roles => :deploy_user do
    puts "Checking system state."

    # NOTE(caleb): This is a hack to make the system setup work in cases where we've updated the Ruby version
    # in the .rbenv-version file. Figure out a better way to do this. See this issue:
    # https://github.com/philc/terraform/issues/3
    rbenv_version = File.read(".rbenv-version").strip
    if Fezzik::Util.capture_output { run "which ruby || true" }.include?(".rbenv") &&
        !Fezzik::Util.capture_output { run "rbenv versions" }.include?(rbenv_version)
      run "rbenv install #{rbenv_version}"
    end

    # This PATH addition is required for Vagrant, which has Ruby installed, but it's not in the default PATH.
    # Include two ruby paths because Vagrant has been known to use both.
    vagrant_ruby_path = "PATH=$PATH:/opt/ruby/bin:/opt/vagrant_ruby/bin"

    which_ruby = run "#{vagrant_ruby_path} which ruby || true"
    if which_ruby.empty?
      fail "The box you're deploying to does not have a ruby installed. Barkeep's deploy needs a ruby " +
           "installed to bootstrap the deploy process. Log in and run `apt-get install ruby`."
    end

    run "cd #{release_path} && #{vagrant_ruby_path} script/system_setup.rb"
    # Now Barkeep's required version of ruby has been installed, so use that.
    run "cd #{release_path} && script/initial_app_setup.rb production"
  end

  remote_task :initial_app_setup, :roles => :deploy_user do
  end

  remote_task :setup_foreman_upstart_scripts, :roles => :deploy_user do
    puts "Copying foreman daemon scripts to /etc/init"
    foreman_command = "foreman export upstart upstart_scripts/ -a #{app} -l /var/log/#{app} -u #{user} " <<
        "-f Procfile > /dev/null"
    run_commands(
      "cd #{release_path}",
      "bundle exec #{foreman_command}",
      # Munge the Foreman-generated upstart conf files so that our app starts on system startup (right after
      # mysql). This is a bit hacky -- Foreman supports templates which you can use to modify the generated
      # upstart conf files. At the time of writing this was not worth the extra effort.
      "echo 'start on started mysql' >> ./upstart_scripts/#{app}.conf",
      "sudo rm /etc/init/#{app}*.conf 2> /dev/null || true",
      "sudo mv upstart_scripts/* /etc/init",
      "sudo rm -R upstart_scripts")
  end

  desc "after the app code has been rsynced, sets up the app's dependencies, like gems"
  remote_task({ :setup_app => [:push, :initial_system_setup, :setup_foreman_upstart_scripts] },
      { :roles => :deploy_user }) do
    puts "Setting up server dependencies."
  end

  desc "starts the server"
  remote_task :start, :roles => :sudo_user do
    puts "Starting from #{Fezzik::Util.capture_output { run "readlink #{current_path}" }}."
    # Upstart will not let you start a started job. Check if it's started already prior to invoking start.
    run "(sudo status #{app} | grep stop) > /dev/null && sudo start #{app} || true"
    puts "Checking that the server is up and running."
    server_is_up?
  end

  desc "stops the applications erver"
  remote_task :stop, :roles => :sudo_user do
    # Upstart will not let you stop a stopped job. Check if it's stopped already prior to invoking stop.
    run "(sudo status #{app} | grep start) > /dev/null && sudo stop #{app} || true"
  end

  desc "restarts the application"
  remote_task({ :restart => [:stop, :start] }, :roles => :sudo_user)

  desc "full deployment pipeline"
  task :deploy => [:deploy_without_tests, :run_integration_tests] do
    puts "#{app} deployed!"
  end

  task :deploy_without_tests => [:push, :symlink, :setup_app, :restart]

  desc "Run the integration tests remotely on the server"
  remote_task :run_integration_tests, :roles => :deploy_user do
    puts "Running the integration tests."
    run "cd #{current_path} && bundle exec rake test:integrations"
  end

  # Ensures that the server is up and can respond to requests.
  remote_task :is_server_up, :roles => :deploy_user do
    server_is_up?
  end

  # This information is exposed via the URL /statusz, so you can tell which version is currently deployed.
  desc "Records information about the current version of Barkeep at the time of deploy"
  task(:write_statusz_file) { Statusz.write_file("/tmp/#{app}/staged/statusz.html") }

  def server_is_up?
    url = "http://localhost:80/"
    begin
      # We try and connect to Barkeep multiple times, because it can take awhile to come up after we start it.
      # We can remove this once we figure out how to make Barkeep start up faster.
      try_n_times(n = 4, timeout = 3) do
        response_code = Fezzik::Util.capture_output {
          run("curl --write-out %{http_code} --silent --output /dev/null #{url}") }.to_i
        if response_code < 200 || response_code >= 500
          raise "The remote server at #{url} is either not responding or giving 500's. " +
            "It may have had trouble starting. You can start troubleshooting by checking the logs in " +
            "#{hostname}:#{deploy_to}/current/logs and #{hostname}:/var/log/#{app}"
        end
      end
    rescue StandardError => error
      puts "#{error}\n#{app} is not responding. It may have had trouble starting."
      exit 1
    end
  end

  def try_n_times(n, sleep_duration, &block)
    attempt = 0
    while attempt < n
      begin
        block.call
      rescue StandardError => error
        attempt += 1
        raise error if attempt >= n
        sleep sleep_duration
      else
        return
      end
    end
  end

end

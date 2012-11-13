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
    nginx_conf = Tilt::ERBTemplate.new("config/system_setup_files/nginx_site.conf.erb").render(Object.new,
        :hostname => hostname,
        :unicorn_socket => env_settings[:unicorn_socket])
    File.open("/tmp/#{app}/staged/config/system_setup_files/nginx_site.conf", "w") { |f| f.write(nginx_conf) }
  end

  desc "performs any necessary setup on the destination servers prior to deployment"
  remote_task :setup, :roles => [:root_user] do
    puts "Setting up servers."
    has_user = Fezzik::Util.capture_output { run "getent passwd #{user} || true" }.size > 0
    unless has_user
      puts "Creating #{user} user."
      # Make a user which has the same authorized keys as root, so we can ssh in as that user.
      run_commands(
          "useradd --create-home --shell /bin/bash #{user}",
          "adduser #{user} --add_extra_groups admin",
          "mkdir -p /home/#{user}/.ssh/",
          "cp ~/.ssh/authorized_keys /home/#{user}/.ssh",
          "chown -R #{user} /home/#{user}/.ssh")
      # Ensure users in the "admin" group can passwordless sudo.
      sudoers_line = "'%admin ALL=NOPASSWD:ALL'"
      run "if test -f /etc/sudoers.local; then " +
          "echo #{sudoers_line} >> /etc/sudoers.local; " +
          "else echo #{sudoers_line} >> /etc/sudoers; fi"
    end
    run "mkdir -p #{deploy_to}/releases && chown #{user} #{deploy_to} #{deploy_to}/releases"
  end

  desc "rsyncs the project from its staging location to each destination server"
  remote_task({ :push => [:stage, :setup] }, { :roles => [:deploy_user] }) do
    puts "Pushing to #{target_host}:#{release_path}."
    # Copy on top of previous release to optimize rsync
    rsync "-q", "--copy-dest=#{current_path}", "/tmp/#{app}/staged/", "#{target_host}:#{release_path}"
  end

  desc "symlinks the latest deployment to /deploy_path/project/current"
  remote_task :symlink, :roles => [:deploy_user] do
    puts "Symlinking current to #{release_path}."
    run "cd #{deploy_to} && ln -fns #{release_path} current"
    # Add a symlink to the current deploy in the deploy user's home directory, for convenience.
    run "rm ~/#{app}_current 2> /dev/null; ln -s #{current_path} ~/#{app}_current"
  end

  remote_task :initial_system_setup, :roles => [:deploy_user] do
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
    run "cd #{release_path} && PATH=$PATH:/opt/ruby/bin:/opt/vagrant_ruby/bin script/system_setup.rb"
    run "cd #{release_path} && script/initial_app_setup.rb production"
  end

  remote_task :generate_foreman_upstart_scripts, :roles => [:deploy_user] do
    puts "Exporting foreman daemon scripts to /etc/init"
    foreman_command = "foreman export upstart upstart_scripts/ -a #{app} -l /var/log/#{app} -u #{user} " <<
        "-f Procfile > /dev/null"
    run_commands("cd #{release_path}",
        "bundle exec #{foreman_command}",
        "sudo rm /etc/init/#{app}*.conf || true",
        "sudo mv upstart_scripts/* /etc/init",
        "rm -R upstart_scripts")

    # Munge the Foreman-generated upstart conf files so that our app starts on system startup (right after
    # mysql). This is a bit hacky -- Foreman supports templates which you can use to modify the generated
    # upstart conf files. At the time of writing this was not worth the extra effort.
    run "echo 'start on started mysql' >> /etc/init/#{app}.conf"
  end

  desc "after the app code has been rsynced, sets up the app's dependencies, like gems"
  remote_task({ :setup_app => [:push, :initial_system_setup, :generate_foreman_upstart_scripts] },
      { :roles => [:deploy_user] }) do
    puts "Setting up server dependencies."
  end

  desc "starts the server"
  remote_task :start, :roles => [:root_user] do
    puts "Starting from #{Fezzik::Util.capture_output { run "readlink #{current_path}" }}."
    # Upstart will not let you start a started job. Check if it's started already prior to invoking start.
    run "(status #{app} | grep stop) > /dev/null && start #{app} || true"
    puts "Checking that the server is up and running."
    server_is_up?
  end

  desc "stops the applications erver"
  remote_task :stop, :roles => [:root_user] do
    # Upstart will not let you stop a stopped job. Check if it's stopped already prior to invoking stop.
    run "(status #{app} | grep start) > /dev/null && stop #{app} || true"
  end

  desc "restarts the application"
  remote_task({ :restart => [:stop, :start] }, :roles => [:root_user])

  desc "full deployment pipeline"
  task :deploy => [:deploy_without_tests, :run_integration_tests] do
    puts "#{app} deployed!"
  end

  task :deploy_without_tests => [:push, :symlink, :setup_app, :restart]

  desc "Run the integration tests remotely on the server"
  remote_task :run_integration_tests, :roles => [:deploy_user] do
    puts "Running the integration tests."
    run "cd #{current_path} && bundle exec rake test:integrations"
  end

  # Ensures that the server is up and can respond to requests.
  remote_task :is_server_up, :roles => [:deploy_user] do
    server_is_up?
  end

  # This information is exposed via the URL /statusz, so you can tell which version is currently deployed.
  desc "Records information about the current version of Barkeep at the time of deploy"
  task(:write_statusz_file) { Statusz.write_file("/tmp/#{app}/staged/statusz.html") }

  def server_is_up?
    begin
      # We try and connect to Barkeep multiple times, because it can take awhile to come up after we start it.
      # We can remove this once we figure out how to make Barkeep start up faster.
      try_n_times(n = 4, timeout = 3) do
        run "curl --silent --show-error --max-time 20 localhost:80/ > /dev/null"
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

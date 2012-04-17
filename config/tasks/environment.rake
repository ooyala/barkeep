require "fileutils"

# Any variables set in deploy.rb with `Fezzik.env` will be saved on the server in two files:
# environment.sh and environment.rb. The first can be loaded into the shell environment before the run script
# is called, and the second is made available to be required into your code. You can use your own
# environment.rb file for development and it will be overwritten by this task when the code deploys.
namespace :fezzik do
  desc "saves variables set by `Fezzik.env` into a local staging area before deployment"
  task :save_environment do
    Fezzik.environments.each do |server, environment|
      root_config_dir = "/tmp/#{app}/#{server}_config"
      FileUtils.mkdir_p root_config_dir
      File.open(File.join(root_config_dir, "environment.rb"), "w") do |file|
        environment.each do |key, value|
          quote = value.is_a?(Numeric) ? '' : '"'
          file.puts "#{key.to_s.upcase} = #{quote}#{value}#{quote}"
        end
      end
      File.open(File.join(root_config_dir, "environment.sh"), "w") do |file|
        environment.each { |key, value| file.puts %[export #{key.to_s.upcase}="#{value}"] }
      end
    end
  end

  # Append to existing actions defined in deploy.rake. This works because we import .rake files alphabetically,
  # so the tasks defined in deploy.rake will be executed before these defined in environment.rake.
  # TODO: Can these be handled through dependencies?
  # task :stage => :save_environment
  # task :push => :push_config
  task :stage do
    Rake::Task["fezzik:save_environment"].invoke
  end

  task :push do
    # Copy over the appropriate configs for the target
    server = target_host.gsub(/^.*@/, "")
    ["environment.rb", "environment.sh"].each do |config_file|
      rsync "-q", "/tmp/#{app}/#{server}_config/#{config_file}",
            "#{target_host}:#{release_path}/#{config_file}"
    end
  end
end

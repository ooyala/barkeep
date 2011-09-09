#
# A recipe for handling deployment rollbacks.
#
# Tasks:
#  * rollback: interactively rollback (or forward) your live deployment
#  * rollback_one: rollback to previous deployment
#  * rollback_to_release: rollback to a specific deployment
#
namespace :fezzik do
  desc "interactively roll back deployment"
  task :rollback do
    target_domain = domain.is_a?(Array) ? domain.first : domain
    releases = `ssh #{target_domain} "cd #{File.dirname(release_path)} && ls"`.split(/\s+/).reverse
    current_release = File.basename(`ssh #{target_domain} "cd #{deploy_to} && readlink current"`).strip
    puts "=== Releases ==="
    puts "0: Abort"
    releases.each_index { |i| puts "#{i+1}: #{releases[i]} #{releases[i] == current_release ? "(current)" : ""}" }
    print "Rollback to release (0): "
    STDOUT.flush
    release_num = STDIN.gets.chomp.to_i

    unless release_num > 0 && release_num <= releases.size
      puts "rollback aborted"
      exit 1
    end

    selected_release = releases[release_num-1]
    Rake::Task["fezzik:rollback_to_release"].invoke(selected_release)
  end

  desc "rolls back deployment to the previous release"
  task :rollback_one do
    target_domain = domain.is_a?(Array) ? domain.first : domain
    current_release = File.basename(`ssh #{target_domain} "cd #{deploy_to} && readlink current"`).strip
    previous_release = %x{
        ssh #{target_domain} "cd #{File.dirname(release_path)} && ls | grep "#{current_release}" -B 1 | head -1"
    }.strip

    if previous_release == current_release
      puts "already at oldest deploy, unable to rollback"
      exit 1
    end

    Rake::Task["fezzik:rollback_to_release"].invoke(previous_release)
  end

  desc "rolls back deployment to a specific release"
  remote_task :rollback_to_release, :selected_release do |t, args|
    selected_release = args[:selected_release]
    puts "rolling #{target_host} back to #{selected_release}"
    run "cd #{deploy_to} && ln -fns #{File.dirname(release_path)}/#{selected_release} current"
    Rake::Task["fezzik:restart"].invoke
  end
end

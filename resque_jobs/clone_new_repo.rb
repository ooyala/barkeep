require "bundler/setup"
require "pathological"
require "timeout"
require "lib/script_environment"
require "lib/resque_job_helper"

class CloneNewRepo
  include ResqueJobHelper
  @queue = :clone_new_repo

  # We're willing to spend up to 5 minutes to clone a repo. This can be necessary for giant repos or
  # when cloning over a slow network connection.
  CLONE_TIMEOUT = 5 * 60

  def self.perform(repo_name, repo_url)
    setup
    # This can take awhile if the repo is very large.
    repo_path = File.join(REPOS_ROOT, repo_name)
    if File.exists?(repo_name)
      message = "Repo path #{repo_path} already exists."
      logger.error message
      raise message
    end

    logger.info "Cloning the repo #{repo_url} into #{repo_path}. If it's large, this may take awhile."
    error = nil
    begin
      # Shell out instead of using Grit::Git.new(repo_path).clone({}, repo_url, repo_path) because
      # Grit doesn't raise an exception when it has trouble cloning a repo, so there's no good error feedback.
      FileUtils.mkdir_p(REPOS_ROOT)
      Timeout::timeout(CLONE_TIMEOUT) do
        run_shell("cd '#{REPOS_ROOT}' && git clone '#{repo_url}' #{repo_name}")
      end
      logger.info "Finished cloning the repo #{repo_url}."
    rescue Timeout::Error => error
      logger.error "Timed out while trying to clone '#{repo_url}'"
    rescue StandardError => error
      logger.error "Unable to clone the repo #{repo_url}"
    ensure
      # Having an empty directory with a bad checkout is not good and can mess up various parts of Barkeep.
      FileUtils.rm_rf(repo_path) if error
    end
  end
end

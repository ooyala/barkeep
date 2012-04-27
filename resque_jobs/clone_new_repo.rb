require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "lib/resque_job_helper"

class CloneNewRepo
  include ResqueJobHelper
  @queue = :clone_new_repo

  # We're willing to spend up to 5 minutes to clone a repo. This can be necessary for giant repos or
  # when cloning over a slow network connection.
  TIMEOUT = 5 * 60

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
    begin
      Grit::Git.with_timeout(CloneNewRepo::TIMEOUT) do
        # If this clone operation requires you to enter a password, it will show a prompt and eventually
        # time out.
        Grit::Git.new(repo_path).clone({}, repo_url, repo_path)
      end

      # Unfortunately, Grit::Git.new(...).clone() will not throw an exception if the repo_url was invalid.
      # It will just... do nothing.
      unless File.exists?(repo_path) && (Grit::Git.new(repo_path).is_valid? rescue false)
        raise "Unable to clone repo. Perhaps the repo at #{repo_url} is invalid or unreachable?"
      end
      logger.info "Finished cloning the repo #{repo_url}."
    rescue Exception => error
      logger.error "Error cloning the repo #{repo_url}: #{error.message}"
      # Having an empty directory with a bad checkout is not good and can mess up various parts of Barkeep.
      # Clean it up.
      FileUtils.rm_rf(repo_path)
    end
  end
end
require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "lib/resque_job_helper"

class DeleteRepo
  include ResqueJobHelper
  @queue = :delete_repo

  # We're willing to spend up to 5 minutes deleting a repo. This can be necessary for giant repos.
  TIMEOUT = 5 * 60

  def self.perform(repo_name)
    setup
    repo = GitRepo.first(:name => repo_name)
    raise message "Error deleting repo: #{repo_name} does not exist in the database." if repo.nil?

    begin
      logger.info "Deleting #{repo_name} from the filesystem."
      FileUtils.rm_rf(repo.path)

      logger.info "Deleting #{repo_name} from the database."
      repo.destroy

      logger.info "Finished deleting the repo #{repo_name}."
    rescue Exception => error
      logger.error "Error deleting the repo #{repo_name}: #{error.message}"
    end
  end
end

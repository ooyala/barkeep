require "bundler/setup"
require "pathological"
require "lib/script_environment"

class CloneNewRepo
  @queue = :clone_new_repo

  def self.perform(repo_name, repo_url)
    logger = Logging.logger = Logging.create_logger("clone_new_repo.log")
    MetaRepo.logger = logger

    # This can take awhile if the repo is very large.
    repo_path = File.join(REPOS_ROOT, repo_name)
    logger.info "Cloning the repo #{repo_url} into #{repo_path}."
    begin
      Grit::Git.new(repo_path).clone({}, repo_url, repo_path)
    rescue Exception => error
      logger.error "Error cloning the repo #{repo_url}: #{error.message}"
    end

    # In the daemons and in the web app, MetaRepo will need to refresh itself.

  end
end
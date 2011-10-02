# Runs "git fetch" for all tracked repos. For each remote which has new commits, a job is queued to insert
# those commits into the database.

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/script_environment"
require "resque"
require "resque_jobs/db_commit_ingest"

class FetchCommits
  @queue = :fetch_commits

  def self.perform
    logger = Logging.logger = Logging.create_logger("fetch_commits.log")
    MetaRepo.logger = logger

    # Reconnect to the database if our connection has timed out.
    Comment.select(1).first rescue nil

    fetch_commits(MetaRepo.instance.repos)
  end

  def self.fetch_commits(grit_repos)
    Logging.logger.info "Fetching new commits."
    grit_repos.each do |repo|
      # In case a repo was removed or moved since this job began, just continue along.
      next unless File.exists?(repo.path)
      db_repo = GitRepo.first(:name => repo.name)
      is_first_time_import = db_repo.commits_dataset.first.nil?
      remotes_to_ingest = fetch_commits_for_repo(repo)

      # We should ingest commits from all remotes (not just the ones that have changed) the first time a
      # repo is imported.
      remotes_to_ingest = repo.remotes.map(&:name) if is_first_time_import

      remotes_to_ingest.reject! { |name| name == "origin/HEAD" }
      Logging.logger.info "Found new commits in repo #{repo.name}." unless remotes_to_ingest.empty?
      remotes_to_ingest.each { |remote| Resque.enqueue(DbCommitIngest, repo.name, remote) }
    end
  end

  # Runs git fetch, and returns the names of the remotes which are either new or were modified.
  def self.fetch_commits_for_repo(grit_repo)
    head_of_remote = { }
    grit_repo.remotes.each { |remote| head_of_remote[remote.name] = remote.commit.sha }

    grit_repo.git.fetch

    # Note: invoking grit_repo.remotes refreshes the remotes, so "remote.commit" will be fresh.
    modified_remotes = grit_repo.remotes.select { |remote| head_of_remote[remote.name] != remote.commit.sha }
    modified_remotes.map(&:name)
  end
end

if $0 == __FILE__
  FetchCommits.perform
end

# Runs "git fetch" for all tracked repos. For each remote which has new commits, a job is queued to insert
# those commits into the database.

require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "resque"
require "resque_jobs/db_commit_ingest"
require "timeout"
require "lib/resque_job_helper"

class FetchCommits
  include ResqueJobHelper
  @queue = :fetch_commits
  FETCH_TIMEOUT = 10 # The per repo timeout, in seconds.

  def self.perform
    setup
    MetaRepo.instance.scan_for_new_repos
    fetch_commits(MetaRepo.instance.repos)
  end

  def self.fetch_commits(grit_repos)
    Logging.logger.info "Fetching new commits."
    grit_repos.each do |repo|
      # In case a repo was removed or moved since this job began, just continue along.
      next unless File.exists?(repo.path)
      db_repo = GitRepo.first(:name => repo.name)
      is_first_time_import = db_repo.commits_dataset.first.nil?
      # Logging.logger.debug("Fetching #{repo.name}")
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

    begin
      # Shell out here instead of using grit_repo.git.fetch, because running git fetch through the shell
      # gives far more useful error information and actually fails if the fetch fails.
      Timeout::timeout(FETCH_TIMEOUT) { run_shell("cd '#{grit_repo.path}' && git fetch") }
    rescue Timeout::Error
      Logging.logger.error "Timed out while fetching commits in the repo '#{grit_repo.name}'"
    rescue StandardError => e
      Logging.logger.error "Unable to fetch new commits in the repo '#{grit_repo.name}'."
    end

    # Note: invoking grit_repo.remotes refreshes the remotes, so "remote.commit" will be fresh.
    modified_remotes = grit_repo.remotes.select { |remote| head_of_remote[remote.name] != remote.commit.sha }
    modified_remotes.map(&:name)
  end

end

if $0 == __FILE__
  FetchCommits.perform
end

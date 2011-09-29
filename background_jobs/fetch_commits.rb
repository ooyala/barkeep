# Runs "git fetch" for all tracked repos. For each remote which has new commits, a job is queued to insert
# those commits into the database.

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/script_environment"

class FetchCommits
  # Returns the names of the remotes which were modified.
  def fetch_commits_for_repo(grit_repo)
    head_of_remote = { }
    grit_repo.remotes.each { |remote| head_of_remote[remote.name] = remote.commit.sha }

    grit_repo.git.fetch

    # Note: invoking grit_repo.remotes refreshes the remotes, so "remote.commit" will be fresh.
    modified_remotes = grit_repo.remotes.select { |remote| head_of_remote[remote.name] != remote.commit.sha }
    modified_remotes.map(&:name)
  end

  def fetch_commits(grit_repos)
    grit_repos.each do |repo|
      modified_remotes = fetch_commits_for_repo(repo)
      unless modified_remotes.empty?
        # TODO(philc): Queue up a job.
      end
    end
  end

  def run
    logger = Logging.logger = Logging.create_logger("fetch_commits.log")
    MetaRepo.logger = logger
    fetch_commits([MetaRepo.instance.repos[2]])
  end
end

if $0 == __FILE__
  FetchCommits.new.run
end

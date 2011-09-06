# This commit importer background task will run git fetch on the repos we're tracking every few seconds and
# ingest new commits. Only when this is run will new commits show up in the UI.

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/script_environment"
require "fileutils"

class CommitImporter
  POLL_FREQUENCY = 15 # How often we run check for new commits by running git fetch.

  # TODO(philc): Implement a reasonable timeout here. We need to be able to paginate our import process
  # such that our commit importer only bites off as much as it can chew.
  TASK_TIMEOUT = 100_000_000 # Effectively infinity. Should be more like 15s.
  @redis = nil

  # True if the parent process has been killed or died.
  def has_become_orphaned?()
    Process.ppid == 1 # Process with ID 1 is the init process, the father of all orphaned processes.
  end

  def run
    logger = Logging.logger = Logging.create_logger("commit_importer.log")
    MetaRepo.instance.logger = logger
    GitHelper.initialize_git_helper(RedisManager.get_redis_instance)

    while true
      exit if has_become_orphaned?

      begin
        DB.disconnect
        exit_status = BackgroundJobs.run_process_with_timeout(100_100_100) do
          MetaRepo.instance.import_new_commits!
        end
      rescue TimeoutError
        logger.info "The commit importer task timed out after #{TASK_TIMEOUT} seconds."
        exit_status = 1
      end

      sleep POLL_FREQUENCY
    end
  end
end

if $0 == __FILE__
  CommitImporter.new.run
end

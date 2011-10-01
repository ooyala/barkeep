# Clockwork is a gem which provides cron-like functionality in Ruby. Run these jobs via
# clockwork clockwork_jobs.rb, or via rake start_clockwork_jobs
$LOAD_PATH.push("../") unless $LOAD_PATH.include?("../")
require "resque_jobs/fetch_commits"
require "clockwork"
include Clockwork

def clear_resque_queue(queue_name)
  Resque.redis.del "queue:#{queue_name}"
end

# We're enqueing Resque jobs to be performed instead of trying to actually perform the work here from within
# the Clockwork process. This is recommended by the Clockwork author. Since Clockwork is a non-parallelized
# process, you don't want perform expensive blocking work here.
# We're clearing out the queue for a job before pushing another item onto its queue, in case the job is
# taking very long to run. We don't want to build up a backlog on the queue because clockwork is moving faster
# than the job is.
handler do |job_name|
  case job_name
  when "fetch_commits"
    clear_resque_queue(fetch_commits)
    Resque.enqueue(FetchCommits)
  end
end

every(45.seconds, "fetch_commits")
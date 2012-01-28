#!/usr/bin/env ruby-local-exec
# Clockwork is a gem which provides cron-like functionality in Ruby.

require "bundler/setup"
require "clockwork"

# TODO(philc): Switch to pathological
project_root = File.expand_path(File.join(File.dirname(__FILE__), "../"))
$LOAD_PATH.push(project_root) unless $LOAD_PATH.include?(project_root)
require "resque_jobs/fetch_commits"
require "resque_jobs/batch_comment_emails"

def clear_resque_queue(queue_name) Resque.redis.del("queue:#{queue_name}") end

# We're enqueing Resque jobs to be performed instead of trying to actually perform the work here from within
# the Clockwork process. This is recommended by the Clockwork maintainer. Since Clockwork is a
# non-parallelized loop, you don't want to perform long-running blocking work here.
# We're clearing out the queue for a job before pushing another item onto its queue, in case the job is
# taking a very long time to run. We don't want to build up a backlog on the queue because clockwork is
# moving faster than the job is.
Clockwork.handler do |job_name|
  case job_name
  when "fetch_commits"
    clear_resque_queue("fetch_commits")
    Resque.enqueue(FetchCommits)
  when "batch_comment_emails"
    clear_resque_queue("batch_comment_emails")
    Resque.enqueue(BatchCommentEmails)
  end
end

Clockwork.every(45.seconds, "fetch_commits")

Clockwork.every(10.seconds, "batch_comment_emails")

Clockwork.run # This is a blocking call.

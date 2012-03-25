#!/usr/bin/env ruby-local-exec
# Clockwork is a gem which provides cron-like functionality in Ruby.

require "bundler/setup"
require "pathological"
require "clockwork"
require "resque_jobs/fetch_commits"
require "resque_jobs/batch_comment_emails"
require "resque_jobs/delete_old_comments_by_demo_users"
require "config/environment"

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
  when "delete_old_comments_by_demo_users"
    clear_resque_queue("delete_old_comments_by_demo_users")
    Resque.enqueue(DeleteOldCommentsByDemoUsers)
  end
end

Clockwork.every(45.seconds, "fetch_commits")

Clockwork.every(10.seconds, "batch_comment_emails")

if defined?(ENABLE_READONLY_DEMO_MODE) && ENABLE_READONLY_DEMO_MODE
  Clockwork.every(30.seconds, "delete_old_comments_by_demo_users")
end

Clockwork.run # This is a blocking call.

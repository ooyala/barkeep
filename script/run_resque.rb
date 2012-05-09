#!/usr/bin/env ruby

require "set"
require "./environment.rb"

# These queues are listed in priority order, from fast and important to slow and unimportant. This ordering
# is critical because you don't want unimportant slow jobs to starve the faster jobs. Resque workers will
# process jobs strictly in this order -- there is no fair round-robin among the queues.
#
# If we ever get the point where we want true concurrency (drain more than one slow queue at the same time),
# then we should run two instances of `rake resque` via Foreman, each with a different set of queues.
queue_order = %W(
  db_commit_ingest
  fetch_commits
  clone_new_repo
  delete_repo
  delete_old_comments_by_demo_users
  deliver_review_request_emails
  deliver_comment_emails
  batch_comment_emails
  deliver_commit_emails
  generate_tagged_diffs
)

resque_job_files = Dir["resque_jobs/*.rb"].map { |file| File.basename(file).sub(/\.rb$/, "") }
if Set.new(queue_order) != Set.new(resque_job_files)
  abort "The ordered list of resque queues does not match the files in resque_jobs/!"
end

RESQUE_WORKERS.times do |i|
  # In production, wait 10 seconds before spawning workers and in between workers to give the web workers a
  # chance to start up quickly without contending for resources.
  sleep 10 if defined?(RACK_ENV) && RACK_ENV == "production"
  spawn({ "QUEUE" => queue_order.join(",") }, "bundle exec rake resque:work")
end

Process.waitall

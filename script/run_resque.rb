#!/usr/bin/env ruby

require "set"
require "./environment.rb"

# These queues are listed in priority order, from fast and important to slow and unimportant. This ordering
# is critical because you don't want unimportant slow jobs to starve the faster jobs. Resque workers will
# process jobs strictly in this order -- there is no fair round-robin among the queues.
#
# The fetch_commits job is done separately by a dedicated queue (see below) because we only want to run one
# instance at a time.
queue_order = %W(
  db_commit_ingest
  clone_new_repo
  delete_repo
  delete_old_comments_by_demo_users
  deliver_review_request_emails
  deliver_comment_emails
  batch_comment_emails
  deliver_commit_emails
  generate_tagged_diffs
)

resque_job_files = Dir["resque_jobs/*.rb"].map { |file| File.basename(file).sub(/\.rb$/, "") }.reject
if Set.new(queue_order) != (Set.new(resque_job_files) - ["fetch_commits"])
  abort "The ordered list of resque queues does not match the files in resque_jobs/!"
end

def run_queues(queues, workers)
  workers.times do |i|
    # In production, wait 10 seconds before spawning workers and in between workers to give the web workers a
    # chance to start up quickly without contending for resources.
    sleep 10 if defined?(RACK_ENV) && RACK_ENV == "production"
    spawn({ "QUEUE" => queues.join(",") }, "bundle exec rake resque:work")
  end
end

run_queues(["fetch_commits"], 1)
run_queues(queue_order, RESQUE_WORKERS)

Process.waitall

#!/usr/bin/env ruby
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
  delete_old_comments_by_demo_users
  deliver_review_request_emails
  deliver_comment_emails
  batch_comment_emails
  deliver_commit_emails
  generate_tagged_diffs
).join(",")

exec "bash -c 'QUEUE=#{queue_order} bundle exec rake resque:work'"
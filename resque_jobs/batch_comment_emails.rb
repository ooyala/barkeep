# Scans for comments which haven't had emails sent for them yet, and enqueues a Resque job to later send an
# email notification for each of those comments. For any given commit that's been commented on, we wait for 2
# minutes before queueing up emails for that commit, in anticipation that more comments on that same commit
# will soon follow. This allows us to batch multiple comments on the same commit together. If there's a
# continuous stream of comments being made on a commit, then we will wait up to a max of 4 minutes before we
# send all comments made thus far. This is so emails don't become noticably delayed.

require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "resque_jobs/deliver_comment_emails"
require "lib/resque_job_helper"

class BatchCommentEmails
  include ResqueJobHelper
  @queue = :batch_comment_emails

  # - filter_by_user_id: an optional parameter which is supplied by the integration tests only.
  def self.perform(filter_by_user_id = nil)
    setup

    comments_dataset = Comment.filter(:has_been_emailed => false)
    comments_dataset = comments_dataset.filter(:user_id => filter_by_user_id) if filter_by_user_id
    comments_by_commit = comments_dataset.all.group_by(&:commit_id)

    two_minutes_ago = Time.now - 2 * 60
    four_minutes_ago = Time.now - 4 * 60

    comments_by_commit.each do |commit_id, comments|
      ready_to_email =
          comments.any? { |comment| comment.created_at <= four_minutes_ago } ||
          comments.all? { |comment| comment.created_at <= two_minutes_ago }

      next unless ready_to_email
      comment_ids = comments.map(&:id)
      logger.info("Queuing up comments #{comment_ids.join(", ")} for emailing.")
      DB.transaction do
        Comment.filter(:id => comment_ids).update(:has_been_emailed => true)
        Resque.enqueue(DeliverCommentEmails, comment_ids)
      end
    end
  end
end

if $0 == __FILE__
  BatchCommentEmails.perform
end

# This job scans for comments which haven't had emails sent for them yet and creates a BackgroundJob to
# send an email notification for that comment. For any given commit that's been commented on, we wait
# for 2 minutes before queueing up an email for that commit in anticipation that more comments on that same
# commit will follow. This allows us to batch multiple comments on the same commit together. If there's a
# continuous stream of comments being made on a commit, if any comments are older than 4 minutes, we send all
# comments made thus far, so that the emails don't become noticably dlayed.

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/script_environment"

class BatchCommentEmails
  POLL_FREQUENCY = 10 # How often we check for new emails in the email task queue.
  TASK_TIMEOUT = 20

  def initialize(logger) @logger = logger end

  # True if the parent process has been killed or died.
  def has_become_orphaned?()
    Process.ppid == 1 # Process with ID 1 is the init process, the father of all orphaned processes.
  end

  def run()
    while true
      exit 0 if has_become_orphaned?

      begin
        DB.disconnect # Do not share a DB connection file descriptor across process boundaries.
        BackgroundJobs.run_process_with_timeout(TASK_TIMEOUT) do
          BatchCommentEmailsWorker.new(@logger).perform()
        end
      rescue TimeoutError
        @logger.warn "The comment email task timed out after #{TASK_TIMEOUT} seconds."
      end

      sleep POLL_FREQUENCY
    end
  end
end

class BatchCommentEmailsWorker
  def initialize(logger) @logger = logger end

  def perform
    comments = Comment.filter(:has_been_emailed => false).all
    comments_by_commit = comments.group_by(&:commit_id)

    two_minutes_ago = Time.now - 2 * 60
    four_minutes_ago = Time.now - 4 * 60

    comments_by_commit.each do |commit_id, comments|
      ready_to_email =
          comments.any? { |comment| comment.created_at <= four_minutes_ago } ||
          comments.all? { |comment| comment.created_at <= two_minutes_ago }

      next unless ready_to_email
      comment_ids = comments.map(&:id)
      @logger.info("Queuing up comments #{comment_ids.join(", ")} for emailing.")
      DB.transaction do
        Comment.filter(:id => comment_ids).update(:has_been_emailed => true)
        BackgroundJob.create(:job_type => BackgroundJob::COMMENTS_EMAIL,
            :params => { :comment_ids => comment_ids }.to_json)
      end
    end
  end
end

if $0 == __FILE__
  BatchCommentEmails.new(Logging.create_logger("batch_comment_emails.log")).run
end

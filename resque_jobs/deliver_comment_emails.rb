# Builds and delivers an email for one or more comments made on a single commit.
require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "lib/resque_job_helper"

# NOTE(philc): This task can take up to 60 seconds, because it must scan through all saved searches to build
# the recipients list for an email. This is expensive at the moment.
class DeliverCommentEmails
  include ResqueJobHelper
  @queue = :deliver_comment_emails

  def self.perform(comment_ids)
    setup
    MetaRepo.instance.scan_for_new_repos

    comments = Comment.filter(:id => comment_ids).all
    return if comments.empty?
    commit = comments.first.commit

    # The commit for this email can become lost if we've stopped tracking this repo. Skip the email if so.
    if commit.nil?
      logger.warn "The commit associated with comment #{comments.first.id} " +
          "is missing. Skipping email."
      return
    end

    logger.info "Sending email for comments #{comments.map(&:id).join(", ")} for commit #{commit.sha}"
    email_has_been_sent = false
    attempts = 0

    # When sending emails, our connection to Gmail's mail server can fail, but that is a recoverable error.
    # Try again a few times if necessary.
    until email_has_been_sent || attempts >= 8
      begin
        attempts += 1
        Emails.send_comment_email(commit, comments)
        email_has_been_sent = true
      rescue Emails::RecoverableEmailError => error
        logger.warn("Recoverable error when sending email for comment ids " +
            " #{comment_ids.inspect}: #{error.message}")
        sleep 2
      end
    end
  end
end
# Builds and delivers an email for review requests.
require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "lib/resque_job_helper"

class DeliverReviewRequestEmails
  include ResqueJobHelper
  @queue = :deliver_review_request_emails

  def self.perform(repo_name, commit_sha, requester_email, emails)
    setup
    MetaRepo.instance.scan_for_new_repos

    commit = MetaRepo.instance.db_commit(repo_name, commit_sha)
    requester = User.find(:email => requester_email)

    # The commit for this email can become lost if we've stopped tracking this repo. Skip the email if so.
    if commit.nil?
      logger.warn "The commit is missing. Skipping email."
      return
    end

    logger.info "Sending review emails requested by #{requester.email} " +
        "to #{emails.join(",")} for commit #{commit.sha}"
    email_has_been_sent = false
    attempts = 0

    # When sending emails, our connection to Gmail's mail server can fail, but that is a recoverable error.
    # Try again a few times if necessary.
    until email_has_been_sent || attempts >= 8
      begin
        Emails.send_review_request_email(requester, commit, emails)
        email_has_been_sent = true
        logger.info "Email sent successfully"
      rescue Emails::RecoverableEmailError => error
        logger.info("Recoverable error when sending email for commit #{commit.sha} in repo #{repo_name}: " +
            error.message)
        sleep 2
      end
    end
  end
end

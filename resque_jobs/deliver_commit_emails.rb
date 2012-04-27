# Builds and delivers an email for a newly imported commit.
require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "lib/resque_job_helper"

# NOTE(philc): This task can take up to 60 seconds, because it must scan through all saved searches to build
# the recipients list for an email. This is expensive at the moment.
class DeliverCommitEmails
  include ResqueJobHelper
  @queue = :deliver_commit_emails

  def self.perform(repo_name, commit_sha)
    setup
    MetaRepo.instance.scan_for_new_repos

    commit = MetaRepo.instance.db_commit(repo_name, commit_sha)
    if commit.nil?
      logger.warn "The commit in repo #{repo_name} with sha #{commit_sha} is missing. " +
          "Skipping the commit import email."
      return
    end

    logger.info "Sending email for commit #{commit.sha} in repo #{repo_name}."
    email_has_been_sent = false
    attempts = 0

    # When sending emails, our connection to Gmail's mail server can fail, but that is a recoverable error.
    # Try again a few times if necessary.
    until email_has_been_sent || attempts >= 8
      begin
        attempts += 1
        Emails.send_commit_email(commit)
        email_has_been_sent = true
      rescue Emails::RecoverableEmailError => error
        logger.warn("Recoverable error when sending email for commit #{commit.sha} in repo #{repo_name}: " +
            error.message)
        sleep 2
      end
    end
  end
end

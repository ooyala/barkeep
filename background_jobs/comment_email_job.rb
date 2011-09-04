# The comment email job polls the background_jobs table for email tasks every few seconds. When a a new task
# is found, it forks a worker which builds and sends the email.

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/script_environment"

class CommentEmailJob
  POLL_FREQUENCY = 3 # How often we check for new emails in the email task queue.
  TASK_TIMEOUT = 10

  def initialize(logger) @logger = logger end

  # True if the parent process has been killed or died.
  def has_become_orphaned?()
    Process.ppid == 1 # Process with ID 1 is the init process, the father of all orphaned processes.
  end

  def run()
    while true
      exit 0 if has_become_orphaned?
      email_job = BackgroundJob.first(:job_type => BackgroundJob::COMMENTS_EMAIL)
      next sleep POLL_FREQUENCY if email_job.nil?

      begin
        DB.disconnect # Do not share a DB connection file descriptor across process boundaries.
        exit_status = BackgroundJobs.run_process_with_timeout(TASK_TIMEOUT) do
          CommentEmailWorker.new(@logger).perform(email_job)
        end
      rescue TimeoutError
        @logger.info "The comment email task timed out after #{TASK_TIMEOUT} seconds."
        exit_status = 1
      end

      # If we sent that last email successfully, we'll continue onto the next email immediately.
      sleep POLL_FREQUENCY if exit_status != 0
    end
  end
end

class CommentEmailWorker
  def initialize(logger) @logger = logger end

  def perform(email_job)
    begin
      comments = Comment.filter(:id => email_job.params["comment_ids"]).all
      commit = comments.empty? ? nil : comments.first.commit
      # If the commit for this email has somehow been lost, like we've stopped tracking this repo,
      # skip this email.
      if comments.empty? || commit.nil?
        @logger.warn "The commit or comments associated with comment_email job #{email_job.id} " +
            "are missing. Skipping email."
      else
        @logger.info "Sending email for comment #{comments.map(&:id).join(", ")}."
        Emails.send_comment_email(commit, comments)
      end
      email_job.delete
    rescue Emails::RecoverableEmailError => error
      @logger.warn("Recoverable error when sending email: #{error.message}")
    rescue Exception => error
      # TODO(philc): Move failed jobs to another table.
      @logger.error("#{error.class} #{error.message}\n#{error.backtrace.join("\n")}")
      raise error
    end
  end
end

if $0 == __FILE__
  # TODO(philc): bundle this logger setup into a helper class.
  logger = Logger.new(File.join(File.dirname(__FILE__), "../log/comment_email_jobs.log"))
  logger.formatter = proc do |severity, datetime, program_name, message|
    time = datetime.strftime "%Y-%m-%d %H:%M:%S"
    "[#{time}] #{message}\n"
  end
  CommentEmailJob.new(logger).run
end

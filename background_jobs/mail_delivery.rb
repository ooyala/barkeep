# The mail delivery task polls the email_tasks table in the database every few seconds. When a new email task
# is found, it forks a worker which sends the email.

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/script_environment"

class MailDelivery
  POLL_FREQUENCY = 3 # How often we check for new emails in the email task queue.
  TASK_TIMEOUT = 10

  def initialize(logger) @logger = logger end

  # True if the parent process has been killed or died.
  def has_become_orphaned?()
    Process.ppid == 1 # Process with ID 1 is the init process, the father of all orphaned processes.
  end

  def run()
    while true
      exit if has_become_orphaned?
      email_task = EmailTask.filter(:status => "pending").order(:id.desc).first

      if email_task.nil?
        sleep POLL_FREQUENCY
        next
      end

      begin
        DB.disconnect # Do not share a DB connection file descriptor across process boundaries.
        exit_status = BackgroundJobs.run_process_with_timeout(TASK_TIMEOUT) do
          MailDeliveryWorker.new(@logger).perform_task(email_task)
        end
      rescue TimeoutError
        @logger.info "The mail task timed out after #{TASK_TIMEOUT} seconds."
        exit_status = 1
      end

      # If we sent that last email successfully, we'll continue onto the next email immediately.
      sleep POLL_FREQUENCY if exit_status != 0
    end
  end
end

class MailDeliveryWorker
  def initialize(logger) @logger = logger end

  def perform_task(email_task)
    begin
      @logger.info "Sending email to #{email_task.to} with subject \"#{email_task.subject}\""
      Emails.deliver_mail(email_task.to, email_task.subject, email_task.body)
      email_task.delete
    rescue => error
      @logger.error("#{error.class} #{error.message} #{error.backtrace}")
      # We're leaving this email task in the database so you can troubleshoot your configuration if there's
      # a problem.
      email_task.last_attempted = Time.now
      email_task.failure_reason = error.to_s
      email_task.status = "failed"
      email_task.save
      raise error
    end
  end
end

if $0 == __FILE__
  logger = Logger.new(File.join(File.dirname(__FILE__), "../log/mail_delivery.log"))
  logger.formatter = proc do |severity, datetime, program_name, message|
    time = datetime.strftime "%Y-%m-%d %H:%M:%S"
    "[#{time}] #{message}\n"
  end
  MailDelivery.new(logger).run
end

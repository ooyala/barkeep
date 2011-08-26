# The mail delivery task polls the email_tasks table in the database every few seconds. When a new email task
# is found, it forks a worker which sends the email.

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/script_environment"

class MailDelivery
  POLL_FREQUENCY = 3 # How often we check for new emails in the email task queue.
  TASK_TIMEOUT = 10

  # True if the parent process has been killed or died.
  def has_become_orphaned?()
    Process.ppid == 1 # Process with ID 1 is the init process, the father of all orphaned processes.
  end

  def run
    while true
      exit if has_become_orphaned?
      email_task = EmailTask.filter(:status => "pending").order(:id.desc).first
      if email_task.nil?
        sleep POLL_FREQUENCY
        next
      end

      begin
        exit_status = BackgroundJobs.run_process_with_timeout(TASK_TIMEOUT) do
          DB.disconnect
          MailDeliveryWorker.new.perform_task(email_task)
        end
      rescue TimeoutError
        puts "The mail task timed out after #{TASK_TIMEOUT} seconds."
        exit_status = 1
      end

      # If we sent that last email successfully, we'll continue onto the next email immediately.
      sleep POLL_FREQUENCY if exit_status != 0
    end
  end
end

class MailDeliveryWorker
  def perform_task(email_task)
    begin
      Emails.deliver_mail(email_task.to, email_task.subject, email_task.body)
      email_task.delete
    rescue => error
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
  MailDelivery.new.run
end

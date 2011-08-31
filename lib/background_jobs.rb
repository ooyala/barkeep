# A utility class for spawning background processes. This is used by background task queues to spawn
# new workers -- for example, an email queue to spawn new workers which send emails.
# Sample usage:
#
#   begin
#     exit_code = BackgroundJobs.run_process_with_timeout(10) do
#       # This is run in a new child process, and so any havoc it causes will not affect the parent process.
#       MailUtils.send_email(:to => "...")
#     end
#   rescue Timeout::Error
#     ...
#   end
#
# A more reliable and efficient way to run background jobs is to use the Resque or BackgroundJob gems,
# but using plain process management like this is much simpler and fits well with our unambitious needs.

require "timeout"

class BackgroundJobs
  # Runs a block of code as a child process and kills it if it hasn't exited after timeout_seconds.
  # This call will block until the child has finished or timeout_seconds has elapsed. Timeouts have a
  # half-second resolution.
  # Raises a Timeout::Error if the process times out. Not that this is not a StandardError, it's an Error,
  # so you must rescue it explicitly.
  def self.run_process_with_timeout(timeout_seconds, &block)
    # We're using our own low-resolution timeout implementation. Simple, but reliable.
    timeout_resolution = 0.5
    child_pid = fork_child_process(&block)
    began = Time.now
    while true
      # This will fetch the exit status of the child process without blocking on it. nil if the child is not
      # yet finished.
      return $?.exitstatus if Process.wait(child_pid, Process::WNOHANG)

      if (Time.now - began >= timeout_seconds)
        Process.kill("HUP", child_pid)
        sleep 0.1
        unless Process.wait(child_pid, Process::WNOHANG)
          sleep 0.5
          Process.kill("KILL", child_pid)
        end
        raise Timeout::Error
      end

      sleep timeout_resolution
    end
  end

  # Runs a block of code as a child process. Returns the pid of that child process.
  def self.fork_child_process(&block)
    child_pid = fork
    if child_pid.nil?
      begin
        yield
      rescue StandardError => error
        puts "Exception will running code in forked child process: #{error.class} #{error.message}"
        puts error.backtrace.join("\n")
        exit 2
      end
      exit
    end
    child_pid
  end
end

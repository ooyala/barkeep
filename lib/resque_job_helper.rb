require "open3"
require "resque"

module ResqueJobHelper
  def self.included(klass) klass.extend(ClassMethods) end

  module ClassMethods
    attr_reader :logger

    # Called by most jobs to automate boilerplate and ensure we don't forget something important
    # (like reconnecting to the DB).
    def setup(log_file_name = nil)
      log_file_name ||= "#{@queue}.log" # @queue will be something like :db_commit_ingest.
      @logger = MetaRepo.logger = Logging.logger = Logging.create_logger(log_file_name)
      reconnect_to_database
    end

    # In any Resque worker, our SQL connection will be invalid because of the fork or if the connection
    # has timed out.
    def reconnect_to_database() DB[:users].select(1).first rescue nil end

    # Runs a command and progressively streams its output and stderr. Throws an error if exit status is nonzero.
    def run_shell(command)
      exit_status = nil
      Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
        stdout.each { |line| Logging.logger.info line.strip }
        stderr.each { |line| Logging.logger.info line.strip }
        exit_status = wait_thread.value.to_i
      end
      raise %Q(The command "#{command}" failed.) unless exit_status == 0
      nil
    end
  end
end

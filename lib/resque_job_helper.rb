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
  end
end

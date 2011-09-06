# Utilities to aid in logging.
class Logging

  # A global logger than misc classes can use.
  class << self
    attr_accessor :logger
  end

  # Creates a logger with our standard options.
  # The logger will have more succinct output than the standard logger. All log files are placed in the "log"
  # directory.
  def self.create_logger(log_file_name)
    if log_file_name.include?("/")
      raise "The file name you pass to Logging.create_logger should be just a file name, not a full path."
    end
    log_file_path = File.join(File.dirname(__FILE__), "../log/", log_file_name)
    FileUtils.touch(log_file_path)
    logger = Logger.new(log_file_path)
    logger.formatter = proc do |severity, datetime, program_name, message|
      time = datetime.strftime "%Y-%m-%d %H:%M:%S"
      "[#{time}] #{message}\n"
    end
    logger
  end
end
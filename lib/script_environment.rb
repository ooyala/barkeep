#
# Loads up our models environment for use by scripts.

require "bundler/setup"
require "pathological"
require "config/environment"
require "grit"
require "resque"
require "lib/ruby_extensions"
require "lib/logging"
require "lib/models"
require "lib/emails"
require "lib/git_helper"
require "lib/meta_repo"
require "redis"
require "lib/redis_manager"
require "lib/backtrace_cleaner"

BacktraceCleaner.monkey_patch_all_exceptions! unless ENV["RACK_ENV"] == "production"

unless ENV["RACK_ENV"] == "test"
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG
  MetaRepo.configure(logger, REPOS_ROOT)
end

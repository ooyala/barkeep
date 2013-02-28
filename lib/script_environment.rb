#
# Loads up our models environment for use by scripts.

require "bundler/setup"
require "pathological"
require "environment"
require "grit"
require "json"
require "resque"
require "lib/ruby_extensions"
require "lib/logging"
require "lib/models"
require "lib/emails"
require "lib/git_helper"
require "lib/meta_repo"
require "redis"
require "lib/redis_manager"
require "backtrace_shortener"

Resque.redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT, :db => REDIS_DB_FOR_RESQUE)

# Make the developer experience better by shortening backtraces.
BacktraceShortener.monkey_patch_the_exception_class! unless ENV["RACK_ENV"] == "production"

unless ENV["RACK_ENV"] == "test"
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG
  MetaRepo.configure(logger, REPOS_ROOT)
end

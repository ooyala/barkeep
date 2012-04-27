# A Resque job which pregenerates and caches the diff for a given commit. We do this after initial ingestion
# of a commit. This makes it so that the first time the syntax colored-diff is accessed, it's ready
# immediately.
require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "resque"
require "lib/resque_job_helper"

class GenerateTaggedDiffs
  include ResqueJobHelper
  @queue = :generate_tagged_diffs

  def self.perform(repo_name, commit_sha)
    setup
    GitDiffUtils.setup(RedisManager.redis_instance)
    MetaRepo.instance.scan_for_new_repos
    grit_commit = MetaRepo.instance.get_grit_repo(repo_name).commits(commit_sha, 1).first
    unless grit_commit
      logger.error "Error: this commit is not found: #{repo_name} #{commit_sha}"
      return
    end
    GitDiffUtils::get_tagged_commit_diffs(repo_name, grit_commit, :warm_the_cache => true)
  end
end

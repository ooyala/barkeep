require File.expand_path(File.join(File.dirname(__FILE__), "../integration_test_helper.rb"))
require "resque_jobs/generate_tagged_diffs"
require "lib/syntax_highlighter"
require "lib/git_diff_utils"

class GenerateTaggedDiffsIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  context "generating diffs" do
    setup do
      stub(RedisManager.redis_instance).get { nil }
      @written_keys = []
      stub(RedisManager.redis_instance).set { |key, value| @written_keys.push(key) }
    end

    should "generate diffs for the given commit" do
      commit = test_repo.commits("9f9c5d87316e5f723d0e9c6a03ddd86ce134ac5e")[0]
      GenerateTaggedDiffs.perform("test_git_repo", commit.sha)
      # NOTE(philc): This assertion isn't particularly strong. It would be nice to be more specific,
      # but this is an effective sanity check to ensure that the highlighting results made it into redis.
      redis_key = SyntaxHighlighter.redis_cache_key("test_git_repo", commit.diffs.first.a_blob)
      assert @written_keys.include?(redis_key)
    end

    should "indicate a file is binary in a diff" do
      commit = test_repo.commits("55d7a76d901e5e5bdf0619b4e1674d4bf427db75")[0]
      data = GitDiffUtils.get_tagged_commit_diffs("test_git_repo", commit)[0]
      assert data.binary?
    end

    should "generate diffs for symlinks" do
      new_symlink = test_repo.commits("b4923aefdf017ce1dd8cf0a0764272de196bddfb")[0]
      data = GitDiffUtils.get_tagged_commit_diffs("test_git_repo", new_symlink)[0]
      assert data.new?
      assert_equal 1, data.lines_added

      changed_symlink = test_repo.commits("4733a0e92e4fb362125c5e9fb065e415f803c3f4")[0]
      data = GitDiffUtils.get_tagged_commit_diffs("test_git_repo", changed_symlink)[0]
      assert_equal 1, data.lines_added
      assert_equal 1, data.lines_removed

      removed_symlink = test_repo.commits("e422237592a7ae409e0c3d72ce0b19d4f0da3180")[0]
      data = GitDiffUtils.get_tagged_commit_diffs("test_git_repo", changed_symlink)[0]
      assert_equal 1, data.lines_removed
    end

    should "not ignore empty files" do
      new_empty = test_repo.commits("b8e935159a8db79275ee30902a9bc3a73fa8163f")[0]
      data = GitDiffUtils.get_tagged_commit_diffs("test_git_repo", new_empty)[0]
      assert data.new?
      assert_equal 0, data.lines.length

      removed_empty = test_repo.commits("6b0b0b5c7274dcbf1df0c18f992af03c790068be")[0]
      data = GitDiffUtils.get_tagged_commit_diffs("test_git_repo", removed_empty)[0]
      assert data.deleted?
      assert_equal 0, data.lines.length
    end

    should "generate diffs for renamed files" do
      renamed = test_repo.commits("d53a8bdaed1bfbea0befaaa904a26d71c9ad8b6a")[0]
      data = GitDiffUtils.get_tagged_commit_diffs("test_git_repo", renamed)[0]
      assert data.renamed?
      assert_equal 1, data.lines_added
      assert_equal 1, data.lines_removed
      assert_equal "spot-the-baneling.txt", data.file_name_before
      assert_equal "spot-the-changeling.txt", data.file_name_after
    end
  end
end

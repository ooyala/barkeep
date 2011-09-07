require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "lib/emails"
require "lib/meta_repo"
require "ostruct"
require "nokogiri"

class MetaRepoTest < Scope::TestCase
  include StubHelper

  setup do
    # This commit added the file "units.txt" and has an author of "phil.crosby@gmail.com"
    @first_commit = "65a0045"
    @repo_name = "test_git_repo"
  end

  setup_once do
    # TODO(philc): The database is disconnected when we start these tests. Unclear why. Reconnect by making
    # a query. Remove this hack.
    Commit.first rescue nil

    # Initialize against sample repo.
    test_git_repo_path = File.join(File.dirname(__FILE__), "../fixtures/test_git_repo")
    MetaRepo.configure(Logger.new("/dev/null"), [test_git_repo_path])
    @@repo = MetaRepo.new
  end

  context "grit_commit" do
    should "return nil for invalid repos and commits" do
      assert_equal nil, @@repo.grit_commit(@repo_name, "non_existant_sha")
      assert_equal nil, @@repo.grit_commit("invalid_repo", @first_commit)
      assert_equal @first_commit, @@repo.grit_commit(@repo_name, @first_commit).id_abbrev
    end
  end

  context "search_options_include_commit" do
    should "find a commit by author" do
      assert_equal false, @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :authors => ["Jones"] })
      assert_equal true, @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :authors => ["Phil"] })
      assert_equal true, @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :authors => ["Phil", "Jones"] })
    end

    should "find a commit by path" do
      assert_equal false, @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :paths => ["nonexistant_file.txt"] })
      assert_equal true, @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :paths => ["units.txt"] })
    end

    should "find a commit by both author and path" do
      assert_equal false, @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :authors => ["phil"], :paths => ["nonexistant_file.txt"] })
      assert_equal true, @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :authors => ["phil"], :paths => ["units.txt"] })
    end

    should "find a commit by branch" do
      commit_on_branch = "4a7d3e5"
      assert_equal false, @@repo.search_options_match_commit?(@repo_name, commit_on_branch,
          { :branches => ["nonexistant_branch"] })
      assert_equal true, @@repo.search_options_match_commit?(@repo_name, commit_on_branch,
          { :branches => ["cheese"] })

      # TODO(philc): This does not work. A bug in grit?
      # assert_equal true, @@repo.search_options_match_commit?(@repo_name, commit_on_branch,
          # { :branches => ["nonexistant_branch", "cheese"] })
    end

    should "return false for a commit which has matching commits in its history, but does not itself match" do
      # NOTE(philc): This exposes a bug where we were improperly parsing the output of git rev-list.
      # git rev-list would return us a commit sha which matched our search criteria, but it was different
      # than the commit ID we were searching for. We needed to compare the two.

      # This commit added the file "strategies.txt" and has an author of "phil.crosby@gmail.com"
      second_commit = "17de311"

      assert_equal false, @@repo.search_options_match_commit?(@repo_name, second_commit,
          { :paths => ["units.txt"] })
    end

    should "return false when searching on a repo which doesn't exist" do
      assert_equal false, @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :repos => ["non-existant-repo"] })
    end
  end
end

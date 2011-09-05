require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "lib/emails"
require "lib/meta_repo"
require "ostruct"
require "nokogiri"

class MetaRepoTest < Scope::TestCase
  include StubHelper

  setup_once do
    # Initialize against sample repo.
    test_git_repo_path = File.join(File.dirname(__FILE__), "../fixtures/test_git_repo")
    @repo = MetaRepo.new(Logger.new("/dev/null"), [test_git_repo_path])
    @first_valid_commit = "65a0045"
  end

  context "grit_commit" do
    should "return nil for invalid repos and commits" do
      assert_equal nil, @repo.grit_commit("test_git_repo", "non_existant_sha")
      assert_equal nil, @repo.grit_commit("invalid_repo", @first_valid_commit)
      assert_equal @first_valid_commit, @repo.grit_commit("test_git_repo", @first_valid_commit).id_abbrev
    end
  end
end

require File.expand_path(File.join(File.dirname(__FILE__), "../unit_test_helper.rb"))
require "lib/git_helper"
require "ostruct"
require "nokogiri"

class SavedSearchTest < Scope::TestCase
  include StubHelper

  context "titles" do
    should "generate a title for all commits" do
      assert_equal "All commits", SavedSearch.new.title
    end

    should "generate a title for commits by an author" do
      assert_equal "Commits by dmac and philc", SavedSearch.new(:authors => "dmac,  philc").title
    end

    should "generate a title for commits by an author in a repo" do
      assert_equal "Commits by kle in the barkeep repo",
          SavedSearch.new(:authors => "kle", :repos => "barkeep").title
    end
  end

  context "commits" do
    setup do
      @user = User.new(:name => "jimbo")
      @commit = stub_commit("commit_id", @user)
      @saved_search = SavedSearch.new
      @git_repo = GitRepo.new
      @dataset = DatasetStub.new
      stub(Commit).select { @dataset }
      stub(GitRepo).first { @git_repo }
    end

    context "commit filtering" do
      setup do
        # SavedSearch.commits calles MetaRepo.find_commits. One of the search options is a proc which filters
        # commits.
        stub(MetaRepo.instance).find_commits do |search_options|
          commits = search_options[:commit_filter_proc].call([@commit.grit_commit])
          { :commits => commits, :count => commits.size }
        end
      end

      should "only include commits which can be found in the database" do
        commits = @saved_search.commits(nil, "before", Time.now).first
        assert_equal [], commits

        @dataset = DatasetStub.new([@commit])
        commits = @saved_search.commits(nil, "before", Time.now).first
        assert_equal [@commit.grit_commit], commits
      end
    end
  end
end

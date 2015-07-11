require File.expand_path(File.join(File.dirname(__FILE__), "../unit_test_helper.rb"))
require "lib/emails"
require "lib/meta_repo"
require "ostruct"
require "nokogiri"

class MetaRepoTest < Scope::TestCase
  include StubHelper

  setup do
    # This commit added the file "units.txt" and has an author of "phil.crosby@gmail.com"
    @first_commit = "65a0045"
    # This commit added the file "strategies.txt" and has an author of "phil.crosby@gmail.com"
    @second_commit = "17de311"
    @third_commit_on_master = "9f9c5d8"

    @repo_name = "test_git_repo"
    @compound_repo_name = "base/test_git_repo"

    @repo_results = [{ :name => @repo_name,          :first_commit =>        "65a0045", :second_commit =>       "17de311",
                                                     :third_master_commit => "9f9c5d8", :first_cheese_commit => "4a7d3e5"},
                     { :name => @compound_repo_name, :first_commit =>        "cdf4874", :second_commit =>       "6282db5",
                                                     :third_master_commit => "30bcea6", :first_cheese_commit => "c7fb18d"}]
  end

  setup_once do
    # TODO(philc): The database is disconnected when we start these tests. Unclear why. Reconnect by making
    # a query. Remove this hack.
    Commit.first rescue nil

    # Initialize against sample repo.
    git_repo_fixtures = File.join(File.dirname(__FILE__), "../fixtures")
    MetaRepo.configure(Logger.new("/dev/null"), git_repo_fixtures)
    @@repo = MetaRepo.instance

    # Access the private git repo inside MetaRepo.
    @@grit_repo = @@repo.get_grit_repo("test_git_repo")
  end

  context "grit_commit" do
    should "return nil for invalid repos and commits" do
      assert_equal nil, @@repo.grit_commit(@repo_name, "non_existant_sha")
      assert_equal nil, @@repo.grit_commit("invalid_repo", @first_commit)
      assert_equal @first_commit, @@repo.grit_commit(@repo_name, @first_commit).id_abbrev
    end
  end

  context "search_options_match_commit?" do
    should "find a commit by author" do
      refute @@repo.search_options_match_commit?(@repo_name, @first_commit, { :authors => ["Jones"] })
      assert @@repo.search_options_match_commit?(@repo_name, @first_commit, { :authors => ["Phil"] })
      assert @@repo.search_options_match_commit?(@repo_name, @first_commit, { :authors => ["Phil", "Jones"] })
    end

    should "find a commit by path" do
      refute @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :paths => ["nonexistant_file.txt"] })
      assert @@repo.search_options_match_commit?(@repo_name, @first_commit, { :paths => ["units.txt"] })
    end

    should "find a commit by both author and path" do
      refute @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :authors => ["phil"], :paths => ["nonexistant_file.txt"] })
      assert @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :authors => ["phil"], :paths => ["units.txt"] })
    end

    should "find a commit by branch" do
      first_commit_on_cheese_branch = "4a7d3e5"
      refute @@repo.search_options_match_commit?(@repo_name, first_commit_on_cheese_branch,
          { :branches => ["nonexistant_branch"] })
      assert @@repo.search_options_match_commit?(@repo_name, first_commit_on_cheese_branch,
          { :branches => ["cheese"] })
      assert @@repo.search_options_match_commit?(@repo_name, first_commit_on_cheese_branch,
          { :branches => ["cheese"] })

      # TODO(philc): This does not work. We should eliminate nonexistant branches from the CLI args before
      # passing them on to git rev-list, as the command will fail with
      #   fatal: ambiguous argument 'origin/nonexistant_branch': unknown revision or path
      # assert @@repo.search_options_match_commit?(@repo_name, first_commit_on_cheese_branch,
          # { :branches => ["nonexistant_branch", "cheese"] })
    end

    should "not find a commit which does not exist on the given branch" do
      commit_not_on_branch = "17de3113"
      refute @@repo.search_options_match_commit?(@repo_name, commit_not_on_branch,
          { :branches => ["cheese"] })
    end

    should "return false for a commit which has matching commits in its history, but does not itself match" do
      # NOTE(philc): This exposes a bug where we were improperly parsing the output of git rev-list.
      # git rev-list would return us a commit sha which matched our search criteria, but it was different
      # than the commit ID we were searching for. We needed to compare the two.
      refute @@repo.search_options_match_commit?(@repo_name, @second_commit, { :paths => ["units.txt"] })
    end

    should "return false when searching on a repo which doesn't exist" do
      refute @@repo.search_options_match_commit?(@repo_name, @first_commit,
          { :repos => ["non-existant-repo"] })
    end
  end

  # TODO(philc): Add tests which require merging results across multiple repos.
  context "find_commits" do
    setup do
      @options = { :direction => "before", :limit => 2 }
    end

    should "find commits matching an author" do
      assert_equal [], @@repo.find_commits(@options.merge(:authors => ["nonexistant author"]))[:commits]

      @repo_results.each do |repo_result|
        result = @@repo.find_commits(@options.merge(:repos => [repo_result[:name]], :authors => ["Phil Crosby"]))
        assert_equal 2, result[:commits].size
        assert_equal ["Phil Crosby"], result[:commits].map { |commit| commit.author.name }.uniq

        # TODO(philc): the test below should work, but it's 1, not 2. Fix that bug.
        # assert_equal 2, results[:count]
      end
    end

    should "find commits matching a branch" do
      assert_equal [], @@repo.find_commits(@options.merge(:branches => ["nonexistant_branch"]))[:commits]

      @repo_results.each do |repo_result|
        result = @@repo.find_commits(@options.merge(:branches => ["cheese"], :repos => [repo_result[:name]]))
        assert_equal [repo_result[:first_cheese_commit], repo_result[:first_commit]], result[:commits].map(&:id_abbrev)
      end
    end

    should "filter out commits olrder than min_commit_date" do
      min_commit_date = @@repo.get_grit_repo("test_git_repo").commit(@second_commit).date
      options = @options.merge(:after => min_commit_date, :branches => ["master"], :limit => 100)

      @repo_results.each do |repo_result|
        commit_ids = @@repo.find_commits(options.merge(:repos => [repo_result[:name]]))[:commits].map(&:id_abbrev)

        # The first commit in the repo should be omitted, because it'so lder than min_commit_date.
        expected = [repo_result[:third_master_commit], repo_result[:second_commit]].sort
        assert_equal expected, (commit_ids & (expected + [repo_result[:first_comit]])).sort
      end
    end

    context "commits_from_repo" do
      setup do
        @git_options = { :author => "Phil Crosby", :cli_args => "master" }
      end

      should "use a commit_filter_proc to filter out commits from the list of results" do
        @repo_results.each do |repo_result|
          grit_repo = @@repo.get_grit_repo(repo_result[:name])

          # This search should include the first_commit and second_commit.
          commit_ids = @@repo.commits_from_repo(grit_repo,  @git_options, 100, :first).map(&:id_abbrev)
          assert commit_ids.include?(repo_result[:first_commit])
          assert commit_ids.include?(repo_result[:second_commit])

          # This search uses a filter_proc to eliminate all commits but the first one.
          commit_filter_proc = proc { |commits| commits.select { |commit| commit.id_abbrev == repo_result[:first_commit] } }
          commit_ids = @@repo.commits_from_repo(grit_repo, @git_options, 2, :first, commit_filter_proc).
              map(&:id_abbrev)
          assert_equal [repo_result[:first_commit]], commit_ids
        end
      end

      should "page through commits and pass each page to commit_filter_proc" do
        @repo_results.each do |repo_result|
          commits_being_filtered = []
          commit_filter_proc = Proc.new do |commits|
            commits_being_filtered.push(commits.map(&:id_abbrev))
            commits.select { |commit| commit.id_abbrev == repo_result[:first_commit] }
          end
          commit_ids = @@repo.commits_from_repo(@@repo.get_grit_repo(repo_result[:name]), @git_options, 1, :first, commit_filter_proc).
              map(&:id_abbrev)

          # commits_from_repo() pages through commits in pages of 2*limit at a time.
          assert_equal [[repo_result[:third_master_commit], repo_result[:second_commit]], [repo_result[:first_commit]]], commits_being_filtered
          assert_equal [repo_result[:first_commit]], commit_ids
        end
      end
    end
  end
end

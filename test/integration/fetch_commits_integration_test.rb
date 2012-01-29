require "bundler/setup"
require "pathological"
require "test/test_helper"
require "test/integration_test_helper"
require "resque_jobs/fetch_commits"
require "resque_jobs/db_commit_ingest"
require "test/db_fixtures_helper"

class FetchCommitsIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  setup_once do
    @@db_repo = GitRepo.first(:name => test_repo.name)
  end

  setup do
    @enqueued_jobs = []
    stub(Resque).enqueue { |*args| @enqueued_jobs.push(args) }
  end

  # We say it's the first import of a repo if it has no commits in the DB yet.
  context "first-time import" do
    setup_once do
      @@db_repo.commits_dataset.destroy
    end

    should "schedule every remote to be imported when it's the first import" do
      # Even if none of the remotes has changed, the first import should schedule all commits to be ingested.
      FetchCommits.perform
      assert @enqueued_jobs.include?([DbCommitIngest, test_repo.name, "origin/master"]),
          "No DbCommitIngest was included for the test repo's master branch."
      assert @enqueued_jobs.include?([DbCommitIngest, test_repo.name, "origin/cheese"]),
          "No DbCommitIngest was included for the test repo's cheese branch."
    end
  end

  # It's not a first time import if we've previously ingested commits for this repo into the DB.
  context "non-first-time import" do
    setup_once do
      head = test_repo.head.commit
      Commit.filter(:sha => head.sha).destroy
      @@commit = Commit.create(:sha => head.sha, :message => head.message, :date => head.authored_date,
        :git_repo_id => @@db_repo.id)
    end

    should "only enqueue a db import for the remotes which have changed" do
      newer_commit, older_commit = test_repo.commits("origin/cheese", 2)
      # Modifying this ref file simulates the remote being out of date, so that git fetch can update it.
      ref_file = File.join(FIXTURES_PATH, TEST_REPO_NAME, ".git/refs/remotes/origin/cheese")
      begin
        File.open(ref_file, "w") { |file| file.write(older_commit.sha) }
        FetchCommits.perform
        # We should not have enqueued a DB import job for origin/master, since it has no new commits.
        assert_equal [[DbCommitIngest, test_repo.name, "origin/cheese"]], @enqueued_jobs
      ensure
        File.open(ref_file, "w") { |file| file.write(newer_commit.sha) }
      end
    end

    should "enqueue no jobs when no remotes have been changed" do
      FetchCommits.perform
      assert_equal [], @enqueued_jobs
    end

    teardown_once do
      @@commit.destroy
    end
  end
end

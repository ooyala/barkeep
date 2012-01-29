require "bundler/setup"
require "pathological"
require "test/test_helper"
require "test/integration_test_helper"
require "resque_jobs/db_commit_ingest"
require "resque_jobs/generate_tagged_diffs"
require "resque_jobs/deliver_commit_emails"

class DbCommitIngestIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  setup do
    @enqueued_jobs = []
    stub(Resque).enqueue do |*args|
      @enqueued_jobs.push(args)
    end
  end

  should "import commits which are not yet in the database" do
    head = test_repo.head.commit
    Commit.filter(:sha => head.sha).destroy
    DbCommitIngest.perform("test_git_repo", "master")

    commits = Commit.filter(:sha => test_repo.head.commit.sha).all
    assert_equal 1, commits.size
    commit = commits.first
    assert_equal head.message, commit.message
    # We enqueue a job to pregenerate this commit's highlighted diffs.
    expected_tasks = [
      [DeliverCommitEmails, test_repo.name, commit.sha],
      [GenerateTaggedDiffs, test_repo.name, commit.sha]]
    assert_equal expected_tasks, @enqueued_jobs[0, 2]

    Commit.filter(:sha => head.sha).delete
  end
end

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

  should "import commits from a new repository without sending email" do
    test_repo_id = GitRepo.find(:name => test_repo.name).id
    Commit.filter(:git_repo_id => test_repo_id).destroy

    DbCommitIngest.perform(test_repo.name, "master")

    expected_tasks = [GenerateTaggedDiffs]
    assert_equal expected_tasks, @enqueued_jobs.map(&:first).uniq
  end

  should "import commits which are not yet in the database and send email" do
    head = test_repo.commit "master"
    Commit.filter(:sha => head.id).destroy
    DbCommitIngest.perform(test_repo.name, "master")

    commits = Commit.filter(:sha => test_repo.commit("master").id).all
    assert_equal 1, commits.size
    commit = commits.first
    assert_equal head.message, commit.message
    # We enqueue a job to pregenerate this commit's highlighted diffs.
    expected_tasks = [
      [DeliverCommitEmails, test_repo.name, commit.sha],
      [GenerateTaggedDiffs, test_repo.name, commit.sha]]
    # Jobs are enqueued in the git ordering, so the latest should be at the end.
    assert_equal expected_tasks, @enqueued_jobs[-2..-1]

    Commit.filter(:sha => head.sha).delete
  end
end

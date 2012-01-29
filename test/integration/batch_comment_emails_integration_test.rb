require "bundler/setup"
require "pathological"
require "test/test_helper"
require "test/integration_test_helper"
require "resque_jobs/batch_comment_emails"
require "resque_jobs/deliver_comment_emails"
require "test/db_fixtures_helper"

class BatchCommentEmailsIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  setup_once do
    commit = test_repo.commits("9f9c5d87316e5f723d0e9c6a03ddd86ce134ac5e")[0]
    Commit.filter(:sha => commit.sha).destroy
    @@commit = Commit.create(:sha => commit.sha, :message => commit.message, :date => commit.authored_date)

    @@comment_one_min_ago = create_comment(@@commit, integration_test_user, Time.now - 60)
    @@comment_three_mins_ago = create_comment(@@commit, integration_test_user, Time.now - 3 * 60)
  end

  teardown_once do
    # Destroying the commit destroys any associated comments.
    @@commit.destroy
  end

  setup do
    @enqueued_jobs = []
    stub(Resque).enqueue do |*args|
      @enqueued_jobs.push(args)
    end
  end

  should "not queue an email for a set of comments if one of them is recent" do
    BatchCommentEmails.perform(integration_test_user.id)
    @@comment_one_min_ago.refresh
    @@comment_three_mins_ago.refresh
    refute @@comment_one_min_ago.has_been_emailed
    refute @@comment_three_mins_ago.has_been_emailed
  end

  context "with a commit older than 4 minutes" do
    setup_once do
      @@comment_four_mins_ago = create_comment(@@commit, integration_test_user, Time.now - 4 * 60)
    end

    should "send all comments for a given commit once it has a comment that's > 4mins old" do
      comments = [@@comment_one_min_ago, @@comment_three_mins_ago, @@comment_four_mins_ago]
      BatchCommentEmails.perform(integration_test_user.id)
      comments.each(&:refresh)
      assert_equal [true, true, true], comments.map(&:has_been_emailed)
      assert_equal 1, @enqueued_jobs.size
      assert_equal [DeliverCommentEmails, comments.map(&:id)], @enqueued_jobs.first
    end

    teardown_once do
      @@comment_four_mins_ago.destroy
    end
  end
end

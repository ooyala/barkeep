require "bundler/setup"
require "pathological"
require "set"
require "test/test_helper"
require "test/integration_test_helper"
require "resque_jobs/deliver_comment_emails"
require "test/db_fixtures_helper"

class DeliverCommentEmailsIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  setup_once do
    test_commit_id = "9f9c5d87316e5f723d0e9c6a03ddd86ce134ac5e"
    commit = test_repo.commits(test_commit_id)[0]
    Commit.filter(:sha => commit.sha).destroy
    @@commit = create_commit(commit, integration_test_user, GitRepo.first(:name => TEST_REPO_NAME))

    @@comments = [
      create_comment(@@commit, integration_test_user, Time.now, :has_been_emailed => true),
      create_comment(@@commit, deleted_test_user, Time.now, :has_been_emailed => true),
    ]
  end

  teardown_once do
    # Destroying the commit destroys any associated comments.
    @@commit.destroy
  end

  setup do
    @sent_emails = []
    stub(Pony).mail { |options| @sent_emails << options }
    # Pretend no one has a saved-search covering this commit, so the comment email recipients are only the
    # authors and commentors of the commit.
    any_instance_of(SavedSearch) do
      stub(SavedSearch).matches_commit? { false }
    end
  end

  should "deliver an email containing all comments" do
    @@comments.each { |comment| DeliverCommentEmails.perform(comment.id) }
    assert_equal 2, @sent_emails.size
    @sent_emails.each do |email|
      # Note that options[:to] may include the author of the test_commit_id (phil.crosby) if he has ever
      # logged in to this Barkeep instance and has a record in the Users table.
      assert email[:to].include?(integration_test_user.email)
      # Deleted user should be ignored.
      assert_equal false, email[:to].include?(deleted_test_user.email)
      assert email[:subject].include?(@@commit.grit_commit.id_abbrev)
      assert email[:html_body].include?(@@comments.first.text)
    end
  end
end

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
    commit = test_repo.commits("9f9c5d87316e5f723d0e9c6a03ddd86ce134ac5e")[0]
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
    @mail_options = []
    stub(Pony).mail { |options| @mail_options << options }
    any_instance_of(SavedSearch) do
      stub(SavedSearch).matches_commit? { false }
    end
  end

  should "deliver an email containing all comments" do
    @@comments.each { |comment| DeliverCommentEmails.perform(comment.id) }
    assert_equal 2, @mail_options.length
    # Deleted user should be ignored.
    expected_emails = [@@commit.grit_commit.author, integration_test_user].map(&:email).sort
    @mail_options.each do |options|
      assert_equal expected_emails, options[:to].sort
      assert options[:subject].include?(@@commit.grit_commit.id_abbrev)
      assert options[:html_body].include?(@@comments.first.text)
    end
  end
end

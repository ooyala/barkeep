require File.expand_path(File.join(File.dirname(__FILE__), "../integration_test_helper.rb"))
require "resque_jobs/deliver_comment_emails"
require "test/db_fixtures_helper"

class DeliverCommentEmailsIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  setup_once do
    commit = test_repo.commits("9f9c5d87316e5f723d0e9c6a03ddd86ce134ac5e")[0]
    Commit.filter(:sha => commit.sha).destroy
    @@commit = create_commit(commit, integration_test_user, GitRepo.first(:name => TEST_REPO_NAME))

    @@comments = [create_comment(@@commit, integration_test_user, Time.now, :has_been_emailed => true)]
  end

  teardown_once do
    # Destroying the commit destroys any associated comments.
    @@commit.destroy
  end

  setup do
    @mail_options = nil
    stub(Pony).mail { |options| @mail_options = options }
    any_instance_of(SavedSearch) do
      stub(SavedSearch).matches_commit? { false }
    end
  end

  should "deliver an email containing all comments" do
    DeliverCommentEmails.perform(@@comments.map(&:id))
    assert_equal integration_test_user.email, @mail_options[:to]
    assert @mail_options[:subject].include?(@@commit.grit_commit.id_abbrev)
    assert @mail_options[:html_body].include?(@@comments.first.text)
  end
end

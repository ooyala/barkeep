require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "resque_jobs/deliver_comment_emails"
require "test/db_fixtures_helper"

class DeliverCommentEmailsIntegrationTest < Scope::TestCase
  setup_once do
    @@integration_test_user = User.first(:email => "integration_test@example.com")

    test_repos = File.join(File.dirname(__FILE__), "../fixtures")
    MetaRepo.configure(Logger.new("/dev/null"), test_repos)
    @@test_repo = MetaRepo.instance.grit_repo_for_name("test_git_repo")

    head = @@test_repo.head.commit
    Commit.filter(:sha => head.sha).destroy
    @@commit = Commit.create(:sha => head.sha, :message => head.message, :date => head.authored_date,
        :user_id => @@integration_test_user.id, :git_repo_id => GitRepo.first(:name => "test_git_repo").id)

    @@comments = [create_comment(@@commit, @@integration_test_user, Time.now, :has_been_emailed => true)]
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
    assert_equal @@integration_test_user.email, @mail_options[:to]
    assert @mail_options[:subject].include?(@@commit.grit_commit.id_abbrev)
    assert @mail_options[:html_body].include?(@@comments.first.text)
  end
end
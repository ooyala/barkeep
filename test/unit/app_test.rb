require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "app"

class AppTest < Scope::TestCase
  include Rack::Test::Methods
  include StubHelper

  def app() Barkeep end

  setup do
    @user = User.new(:email => "thebarkeep@barkeep.com", :name => "The Barkeep")
    any_instance_of(Barkeep, :current_user => @user)
  end

  context "comments" do
    setup do
      @comment = Comment.new(:text => "howdy ho", :created_at => Time.now)
      stub(@comment).user { @user }
      @commit = stub_commit(@user)
      meta_repo = MetaRepo.new(Logger.new(STDERR), [])
      stub(MetaRepo).instance { meta_repo }

      stub(meta_repo).db_commit { @commit }
    end

    should "posting a comment should trigger an email" do
      @background_job_params = nil
      stub(Comment).create { @comment }
      stub(BackgroundJob).create { |params| @background_job_params = params; BackgroundJob.new }
      post "/comment"
      # TODO(philc): Make a stronger assertion, e.g. about who this email is being sent to.
      assert_equal BackgroundJob::COMMENTS_EMAIL, @background_job_params[:job_type]
    end
  end
end

require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "app"

class AppTest < Scope::TestCase
  include Rack::Test::Methods

  def app() Barkeep end

  setup do
    @user = User.new(:email => "thebarkeep@barkeep.com", :name => "The Barkeep")
    any_instance_of(Barkeep, :current_user => @user)
  end

  context "comments" do
    setup do
      @comment = Comment.new(:text => "howdy ho", :created_at => Time.now)
      stub(@comment).user { @user }
      stub(Commit).filter { [Commit.new()] }
    end

    should "posting a comment should trigger an email" do
      @email_task_params = nil
      stub(Comment).create { @comment }
      stub(EmailTask).create { |params| @email_task_params = params; EmailTask.new }
      post "/comment"
      # TODO(philc): Make a stronger assertion, e.g. about who this email is being sent to.
      assert_equal false, @email_task_params.nil?
    end

  end
end

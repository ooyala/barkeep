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
      MetaRepo.configure(Logger.new(STDERR), [])
      stub(MetaRepo.instance).db_commit { @commit }
    end

    should "posting a comment should create a comment" do
      @comment_params = nil
      stub(Comment).create { |params| @comment_params = params; @comment }
      post "/comment", :text => "great job"
      assert_equal "great job", @comment_params[:text]
    end
  end
end

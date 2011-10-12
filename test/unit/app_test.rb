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
      stub(@comment).format { "fancified" }
      @commit = stub_commit("commit_id", @user)
      @meta_repo = MetaRepo.new("/dev/null")
      stub(MetaRepo).instance { @meta_repo }
      stub(@meta_repo).db_commit { @commit }
    end

    should "posting a comment should create a comment" do
      @comment_params = nil
      stub(Comment).create { |params| @comment_params = params; @comment }
      post "/comment", :text => "great job"
      assert_equal "great job", @comment_params[:text]
    end

    should "be previewed" do
      mock(@meta_repo).db_commit("repo1", "asdf123") { @commit }
      mock(Comment).new(:text => "foobar", :commit => @commit) { @comment }
      post "/comment_preview", :text => "foobar", :repo_name => "repo1", :sha => "asdf123"
      assert_equal "fancified", last_response.body
    end
  end
end

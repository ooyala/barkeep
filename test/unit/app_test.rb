require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "app"

class AppTest < Scope::TestCase
  include Rack::Test::Methods
  include StubHelper

  def app() Barkeep end

  setup do
    @@repo = MetaRepo.new("/dev/null")
    stub(MetaRepo).instance { @@repo }
    @user = User.new(:email => "thebarkeep@barkeep.com", :name => "The Barkeep")
    any_instance_of(Barkeep, :current_user => @user)
  end

  context "comments" do
    setup do
      @comment = Comment.new(:text => "howdy ho", :created_at => Time.now)
      stub(@comment).user { @user }
      stub(@comment).filter_text { "fancified" }
      @commit = stub_commit("commit_id", @user)
      stub(@@repo).db_commit { @commit }
    end

    should "posting a comment should create a comment" do
      @comment_params = nil
      stub(Comment).create do |params|
        @comment_params = params
        stub(@comment).commit { @commit }
      end
      post "/comment", :text => "great job"
      assert_equal "great job", @comment_params[:text]
    end

    should "be previewed" do
      mock(@@repo).db_commit("repo1", "asdf123") { @commit }
      mock(Comment).new(:text => "foobar", :commit => @commit) { @comment }
      post "/comment_preview", :text => "foobar", :repo_name => "repo1", :sha => "asdf123"
      assert_equal "fancified", last_response.body
    end
  end

  context "api routes" do
    context "commit" do
      should "return a 404 and human-readable error message when given a bad repo or sha" do
        stub(@@repo).db_commit("my_repo", "sha1") { nil } # No results
        get "/api/commits/my_repo/sha1"
        assert_equal 404, last_response.status
        assert JSON.parse(last_response.body).include? "message"
      end

      should "return the relevant metadata for an unapproved commit as expected" do
        unapproved_commit = stub_commit("sha1", @user)
        stub(unapproved_commit).approved_by_user_id { nil }
        stub(unapproved_commit).comment_count { 0 }
        stub(Commit).prefix_match("my_repo", "sha1") { unapproved_commit }
        get "/api/commits/my_repo/sha1"
        assert_equal 200, last_response.status
        result = JSON.parse(last_response.body)
        refute result["approved"]
        assert_equal 0, result["comment_count"]
        assert_match /commits\/my_repo\/sha1$/, result["link"]
      end

      should "return the relevant metadata for an approved commit as expected" do
        approved_commit = stub_commit("sha1", @user)
        stub(approved_commit).approved_by_user_id { 42 }
        stub(approved_commit).approved_by_user { @user }
        stub(approved_commit).comment_count { 155 }
        stub(Commit).prefix_match("my_repo", "sha2") { approved_commit }
        get "/api/commits/my_repo/sha2"
        assert_equal 200, last_response.status
        result = JSON.parse(last_response.body)
        assert result["approved"]
        assert_equal 155, result["comment_count"]
        assert_equal "The Barkeep <thebarkeep@barkeep.com>", result["approved_by"]
      end
    end
  end
end

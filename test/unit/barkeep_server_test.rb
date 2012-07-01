require File.expand_path(File.join(File.dirname(__FILE__), "../unit_test_helper.rb"))
require "barkeep_server"

class BarkeepServerTest < Scope::TestCase
  include Rack::Test::Methods
  include StubHelper

  def app() BarkeepServer.new(StubPinion.new) end

  setup do
    @@repo = MetaRepo.new("/dev/null")
    stub(MetaRepo).instance { @@repo }
    @user = User.new(:email => "thebarkeep@barkeep.com", :name => "The Barkeep")
    any_instance_of(BarkeepServer, :current_user => @user)
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

  context "search_by_sha" do
    def setup_repo(name)
      repo = mock(name)
      stub(repo).name { name }
      repo
    end

    setup do
      # There are two repos in our system.
      @repo1 = setup_repo("repo1")
      @repo2 = setup_repo("repo2")
      @commit = stub_commit("sha_123", @user)
      stub(@@repo).repos { [@repo1, @repo2] }
    end

    should "search all repos and return 404 for sha that it could not find" do
      stub(@@repo).db_commit("repo1", "sha") { }
      stub(Commit).prefix_match("repo1", "sha") { }

      stub(@@repo).db_commit("repo1", "sha") { }
      stub(Commit).prefix_match("repo2", "sha") { }

      get "/commits/search/by_sha", :sha => "sha"
      assert_status 404
    end

    should "return the _first_ matching commit for the prefix" do
      mock(@@repo).db_commit("repo1", "sha") { @commit }
      dont_allow(@@repo).db_commit("repo2", "sha")

      get "/commits/search/by_sha", :sha => "sha"
      assert_status 302
      assert_match last_response.location, /sha_123/
      assert_match last_response.location, /repo1/
    end

    should "search all repos and find a matching commit" do
      mock(Commit).prefix_match("repo1", "sha", true) { nil }
      mock(@@repo).db_commit("repo1", "sha") { nil }
      mock(@@repo).db_commit("repo2", "sha") { @commit }

      get "/commits/search/by_sha", :sha => "sha"
      assert_status 302
      assert_match last_response.location, /sha_123/
      assert_match last_response.location, /repo2/
    end

    should "try prefix match on commits" do
      stub(@@repo).db_commit("repo1", "sha") {  }
      mock(Commit).prefix_match("repo1", "sha", true) { @commit }
      dont_allow(@@repo).db_commit("repo2", "sha")

      get "/commits/search/by_sha", :sha => "sha"
      assert_status 302
      assert_match last_response.location, /sha_123/
      assert_match last_response.location, /repo1/
    end
  end

  context "/admin" do

    should "only allow users with admin permission" do
      get "/admin"
      assert_status 400

      post "/admin/users/"
    end

    context "with admin logged in" do
      setup do
        @admin = User.new(:email => "admin@barkeep.com", :name => "The Admin", :permission => "admin")
        any_instance_of(BarkeepServer, :current_user => @admin)
      end

      should "allow access to /admin/users" do
        get "/admin/users"
        assert_status 200
      end

      should "show a list of repos" do
        meta_repo = MetaRepo.new(FIXTURES_PATH)
        stub(MetaRepo).instance { meta_repo }
        get "/admin/repos"
        assert_status 200
        dom_response.css("repoList").text.include?(meta_repo.repos.first.name)
      end

      teardown do
        any_instance_of(BarkeepServer, :current_user => @user)
      end
    end
  end
end

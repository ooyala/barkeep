require File.expand_path(File.join(File.dirname(__FILE__), "../unit_test_helper.rb"))

require "barkeep_server"
require "lib/api_routes"

class ApiTest < Scope::TestCase
  include Rack::Test::Methods
  include StubHelper

  def app() BarkeepServer.new end

  setup do
    @@repo = MetaRepo.new("/dev/null")
    stub(MetaRepo).instance { @@repo }
    @user = User.new(:email => "thebarkeep@barkeep.com", :name => "The Barkeep")
    any_instance_of(BarkeepServer, :current_user => @user)
  end

  context "get commit" do
    def approved_stub_commit(sha)
      commit = stub_commit(sha, @user)
      stub_many commit, :approved_by_user_id => 42, :approved_by_user => @user, :comment_count => 155
      commit
    end

    should "return a 404 and human-readable error message when given a bad repo or sha" do
      stub(@@repo).db_commit("my_repo", "sha1") { nil } # No results
      get "/api/commits/my_repo/sha1"
      assert_status 404
      assert JSON.parse(last_response.body).include? "error"
    end

    should "return the relevant metadata for an unapproved commit as expected" do
      unapproved_commit = stub_commit("sha1", @user)
      stub_many unapproved_commit, :approved_by_user_id => nil, :comment_count => 0
      stub(Commit).prefix_match("my_repo", "sha1") { unapproved_commit }
      get "/api/commits/my_repo/sha1"
      assert_status 200
      result = JSON.parse(last_response.body)
      refute result["approved"]
      assert_equal 0, result["comment_count"]
      assert_match %r[commits/my_repo/sha1$], result["link"]
    end

    should "return the relevant metadata for an approved commit as expected" do
      approved_commit = approved_stub_commit("sha1")
      stub(Commit).prefix_match("my_repo", "sha1") { approved_commit }
      get "/api/commits/my_repo/sha1"
      assert_status 200
      result = JSON.parse(last_response.body)
      assert result["approved"]
      assert_equal 155, result["comment_count"]
      assert_equal "The Barkeep <thebarkeep@barkeep.com>", result["approved_by"]
    end

    should "allow for fetching multiple shas at once using the post route" do
      commit1 = approved_stub_commit("sha1")
      commit2 = approved_stub_commit("sha2")
      stub(Commit).prefix_match("my_repo", "sha1") { commit1 }
      stub(Commit).prefix_match("my_repo", "sha2") { commit2 }
      post "/api/commits/my_repo", :shas => "sha1,sha2"
      assert_status 200
      result = JSON.parse(last_response.body)
      assert_equal 2, result.size
      ["sha1", "sha2"].each { |sha| assert_equal 155, result[sha]["comment_count"] }
    end

    should "only return requested fields" do
      approved_commit = approved_stub_commit("sha1")
      stub(Commit).prefix_match("my_repo", "sha1") { approved_commit }
      get "/api/commits/my_repo/sha1?fields=approved"
      assert_status 200
      result = JSON.parse(last_response.body)
      assert result["approved"]
      assert_equal 1, result.size
    end
  end

  context "api authentication" do
    def check_response
      assert_status 200
      assert_equal 155, JSON.parse(last_response.body)["comment_count"]
    end

    def create_request_url(url, params)
      "#{url}?#{params.keys.sort.map { |k| "#{k}=#{params[k]}" }.join("&") }"
    end

    def get_with_signature(url, params)
      signature = OpenSSL::HMAC.hexdigest "sha1", "apisecret", "GET #{create_request_url(url, params)}"
      params[:signature] = signature
      get create_request_url(url, params)
    end

    setup do
      # Temporarily make every api route require authentication
      @whitelist_routes = BarkeepServer::AUTHENTICATION_WHITELIST_ROUTES.dup
      @whitelist_routes.each { |route| BarkeepServer::AUTHENTICATION_WHITELIST_ROUTES.delete route }

      approved_commit = stub_commit("sha1", @user)
      stub_many approved_commit, :approved_by_user_id => 42, :approved_by_user => @user, :comment_count => 155
      stub(Commit).prefix_match("my_repo", "sha1") { approved_commit }

      stub(User).[](:api_key => "apikey") { @user }
      stub_many @user, :api_secret => "apisecret", :api_key => "apikey"
      @base_url = "/api/commits/my_repo/sha1"
      @params = { :api_key => "apikey", :timestamp => Time.now.to_i }
    end

    teardown do
      @whitelist_routes.each { |route| BarkeepServer::AUTHENTICATION_WHITELIST_ROUTES << route }
    end

    should "return proper result for up-to-date, correctly signed request" do
      get_with_signature @base_url, @params
      check_response
    end

    should "reject requests without all the required fields" do
      [:timestamp, :api_key].each do |missing_field|
        params = @params.dup
        params.delete missing_field
        get_with_signature @base_url, params
        assert_status 400
      end
    end

    should "reject unsigned requests" do
      get create_request_url(@base_url, @params)
      assert_status 400
    end

    should "reject requests with bad api keys" do
      stub(User).[](:api_key => "apikey") { nil }
      get_with_signature @base_url, @params
      assert_status 400
    end

    should "reject requests with malformed or outdated timestamps" do
      ["asdf", (Time.now - (525_600 * 60)).to_i, (Time.now + 60).to_i].each do |bad_timestamp|
        @params[:timestamp] = bad_timestamp
        get_with_signature @base_url, @params
        assert_status 400
      end
    end

    should "reject requests with bad signatures" do
      @params[:signature] = "asdf"
      get create_request_url(@base_url, @params)
      assert_status 400
    end

    context "admin routes" do
      setup { BarkeepServer::ADMIN_ROUTES << @base_url }
      teardown { BarkeepServer::ADMIN_ROUTES.delete @base_url }

      should "allow requests for admin-only routes made by admin users" do
        mock(@user).admin? { true }
        get_with_signature @base_url, @params
        check_response
      end

      should "reject requests for admin-only routes made by non-admin users" do
        mock(@user).admin? { false }
        get_with_signature @base_url, @params
        assert_status 403
      end
    end
  end
end

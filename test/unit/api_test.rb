require File.expand_path(File.join(File.dirname(__FILE__), "../unit_test_helper.rb"))

require "app"
require "lib/api_routes"

class AppTest < Scope::TestCase
  include Rack::Test::Methods
  include StubHelper

  def app() Barkeep.new(StubPinion.new) end

  setup do
    @@repo = MetaRepo.new("/dev/null")
    stub(MetaRepo).instance { @@repo }
    @user = User.new(:email => "thebarkeep@barkeep.com", :name => "The Barkeep")
    any_instance_of(Barkeep, :current_user => @user)
  end

  context "get commit" do
    should "return a 404 and human-readable error message when given a bad repo or sha" do
      stub(@@repo).db_commit("my_repo", "sha1") { nil } # No results
      get "/api/commits/my_repo/sha1"
      assert_status 404
      assert JSON.parse(last_response.body).include? "message"
    end

    should "return the relevant metadata for an unapproved commit as expected" do
      unapproved_commit = stub_commit("sha1", @user)
      stub(unapproved_commit).approved_by_user_id { nil }
      stub(unapproved_commit).comment_count { 0 }
      stub(Commit).prefix_match("my_repo", "sha1") { unapproved_commit }
      get "/api/commits/my_repo/sha1"
      assert_status 200
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
      assert_status 200
      result = JSON.parse(last_response.body)
      assert result["approved"]
      assert_equal 155, result["comment_count"]
      assert_equal "The Barkeep <thebarkeep@barkeep.com>", result["approved_by"]
    end
  end

  context "api authentication" do
    def check_response
      assert_status 200
      assert_equal 155, JSON.parse(last_response.body)["comment_count"]
    end

    def create_request_url(params)
      "#{@base_url}?#{params.keys.sort.map { |k| "#{k}=#{params[k]}" }.join("&") }"
    end

    setup do
      # Temporarily make every api route require authentication
      @whitelist_routes = Barkeep::AUTHENTICATION_WHITELIST_ROUTES.dup
      @whitelist_routes.each { |route| Barkeep::AUTHENTICATION_WHITELIST_ROUTES.delete route }

      approved_commit = stub_commit("sha1", @user)
      stub(approved_commit).approved_by_user_id { 42 }
      stub(approved_commit).approved_by_user { @user }
      stub(approved_commit).comment_count { 155 }
      stub(Commit).prefix_match("my_repo", "sha1") { approved_commit }

      stub(User).[](:api_key => "apikey") { @user }
      stub(@user).api_secret { "apisecret" }
      stub(@user).api_key { "apikey" }
      @base_url = "/api/commits/my_repo/sha1"
      @params = { :api_key => "apikey", :timestamp => Time.now.to_i }
    end

    teardown do
      @whitelist_routes.each { |route| Barkeep::AUTHENTICATION_WHITELIST_ROUTES << route }
    end

    should "return proper result for up-to-date, correctly signed request" do
      signature = OpenSSL::HMAC.hexdigest "sha1", "apisecret", "GET #{create_request_url(@params)}"
      @params[:signature] = signature
      get create_request_url(@params)
      check_response
    end

    should "reject requests without all the required fields" do
      [:timestamp, :api_key].each do |missing_field|
        params = @params.dup
        params.delete missing_field
        signature = OpenSSL::HMAC.hexdigest "sha1", "apisecret", "GET #{create_request_url(params)}"
        params[:signature] = signature
        get create_request_url(@params)
        assert_status 400
      end
    end

    should "reject unsigned requests" do
      get create_request_url(@params)
      assert_status 400
    end

    should "reject requests with bad api keys" do
      stub(User).[](:api_key => "apikey") { nil }
      signature = OpenSSL::HMAC.hexdigest "sha1", "apisecret", "GET #{create_request_url(@params)}"
      @params[:signature] = signature
      get create_request_url(@params)
      assert_status 400
    end

    should "reject requests with malformed or outdated timestamps" do
      ["asdf", (Time.now - (525_600 * 60)).to_i, (Time.now + 60).to_i].each do |bad_timestamp|
        @params[:timestamp] = bad_timestamp
        signature = OpenSSL::HMAC.hexdigest "sha1", "apisecret", "GET #{create_request_url(@params)}"
        @params[:signature] = signature
        get create_request_url(@params)
        assert_status 400
      end
    end

    should "reject requests with bad signatures" do
      @params[:signature] = "asdf"
      get create_request_url(@params)
      assert_status 400
    end

    context "admin routes" do
      setup { Barkeep::ADMIN_ROUTES << @base_url }
      teardown { Barkeep::ADMIN_ROUTES.delete @base_url }

      should "allow requests for admin-only routes made by admin users" do
        mock(@user).admin? { true }
        signature = OpenSSL::HMAC.hexdigest "sha1", "apisecret", "GET #{create_request_url(@params)}"
        @params[:signature] = signature
        get create_request_url(@params)
        check_response
      end

      should "reject requests for admin-only routes made by non-admin users" do
        mock(@user).admin? { false }
        signature = OpenSSL::HMAC.hexdigest "sha1", "apisecret", "GET #{create_request_url(@params)}"
        @params[:signature] = signature
        get create_request_url(@params)
        assert_status 400
      end
    end
  end
end

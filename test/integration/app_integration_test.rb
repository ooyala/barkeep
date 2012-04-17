require "bundler/setup"
require "pathological"
require "test/integration_test_helper"

SERVER = "http://localhost:8040"

class AppIntegrationTest < Scope::TestCase
  include HttpTestHelper
  def server() SERVER end

  setup_once do
    ensure_reachable!(SERVER, "Barkeep")
  end

  context "signing in" do
    should "show a selection of OpenID providers" do
      # This page is reached when the user tries to log in and the server is configured with more than one
      # openID provider. Our default configuration just has google as the OpenID provider.
      get "/signin/select_openid_provider"
      assert_status 200
      assert_equal ["www.google.com"], dom_response.css("#openIdProviders li").map(&:text).map(&:strip)
    end
  end
end

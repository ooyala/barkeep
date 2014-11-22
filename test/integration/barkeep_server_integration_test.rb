require "bundler/setup"
require "pathological"
require "test/integration_test_helper"

require "environment.rb"

PORT = (defined?(RACK_ENV) && RACK_ENV == "production") ? 80 : 8040
SERVER = "http://localhost:#{PORT}"

class BarkeepServerIntegrationTest < Scope::TestCase
  include HttpTestHelper
  def server() SERVER end

  setup_once do
    ensure_reachable!(SERVER, "Barkeep")
  end

  context "signing in" do
    should "show a selection of OpenID providers" do
      # This page is reached when the user tries to log in and the server is configured with more than one
      # openID provider. Our default configuration just has google as the OpenID provider.
      get "/signin/select_signin_provider"
      assert_status 200
      assert_equal ["www.google.com"], dom_response.css("#openIdProviders li").map(&:text).map(&:strip)
    end
  end
end

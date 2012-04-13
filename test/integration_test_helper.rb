require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "minitest/autorun"
require "scope"
require "test/http_test_helper"
require "rr"
require "test/stub_helper"

FIXTURES_PATH = File.join(File.dirname(__FILE__), "/fixtures")
TEST_REPO_NAME = "test_git_repo"

module IntegrationTestHelper
  def integration_test_user
    @integration_test_user ||= User.first(:email => "integration_test@example.com")
  end

  def test_repo
    unless @test_repo
      MetaRepo.configure(Logger.new("/dev/null"), FIXTURES_PATH)
      @test_repo = MetaRepo.instance.grit_repo_for_name(TEST_REPO_NAME)
    end
    @test_repo
  end
end

# TODO(philc): Some of our integration tests use stubbing. They're really half-integration, half
# unit. We should remove the need for these stubs.
module Scope
  class TestCase
    include RR::Adapters::MiniTest
  end
end
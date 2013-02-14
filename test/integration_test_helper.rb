require "bundler/setup"
require "pathological"
require "test/test_helper"
require "test/http_test_helper"
require "rr"

module IntegrationTestHelper
  def integration_test_user
    @integration_test_user ||= User.first(:email => "integration_test@example.com")
  end

  def deleted_test_user
    @deleted_test_user ||= User.first(:email => "deleted_for_tests@example.com")
  end

  def test_repo
    unless @test_repo
      # Import this test repo fresh. A common annoyance is that you move your barkeep checkout, and this
      # test repo now has a differnet path on disk, which confuses barkeep.
      old_test_repo = GitRepo.first(:name => TEST_REPO_NAME)
      old_test_repo.destroy if old_test_repo && old_test_repo.path != File.join(FIXTURES_PATH, TEST_REPO_NAME)
      MetaRepo.configure(Logger.new("/dev/null"), FIXTURES_PATH)
      @test_repo = MetaRepo.instance.get_grit_repo(TEST_REPO_NAME)
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

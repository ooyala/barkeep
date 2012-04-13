# Ensures that this background job can successfully clone a new repo.
require "bundler/setup"
require "pathological"
require "test/test_helper"
require "test/integration_test_helper"
require "resque_jobs/clone_new_repo"

class CloneNewRepoIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  setup_once do
    @@test_repo_name = "clone_repo_integration_test"

    # We could also clone this repo from git@github.com:ooyala/barkeep_integration_tests.git, but that takes
    # about 5 seconds. Cloning from the local disk is much faster.
    @@test_repo_url = File.join(File.dirname(__FILE__), "../fixtures/test_git_repo")

    delete_repo(@@test_repo_name)
  end

  teardown_once do
    delete_repo(@@test_repo_name)
  end

  should "clone a new repo to the correct place on disk" do
    assert_equal false, File.exists?(repo_path(@@test_repo_name))
    CloneNewRepo.perform(@@test_repo_name, @@test_repo_url)
    assert File.exists?(repo_path(@@test_repo_name))

    # Ensure it successfully completed a full clone (i.e. commits can now be read by Grit).
    first_commit = "65a0045e7ac5329d76e6644aa2fb427b78100a7b"
    grit = Grit::Repo.new(repo_path(@@test_repo_name))
    assert_equal 1, grit.commits(first_commit).size
  end

  def repo_path(repo_name) File.join(REPOS_ROOT, @@test_repo_name) end
  def delete_repo(repo_name)
    FileUtils.rm_rf(repo_path(repo_name)) if File.exists?(repo_path(repo_name))
  end
end

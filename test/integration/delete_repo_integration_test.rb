# Ensures that this background job can successfully delete a repo.
require "bundler/setup"
require "pathological"
require "test/test_helper"
require "test/integration_test_helper"
require "resque_jobs/clone_new_repo"
require "resque_jobs/delete_repo"

class DeleteRepoIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  setup_once do
    @@test_repo_name = "delete_repo_integration_test"

    # We could also clone this repo from git@github.com:ooyala/barkeep_integration_tests.git, but that takes
    # about 5 seconds. Cloning from the local disk is much faster.
    @@test_repo_url = File.join(File.dirname(__FILE__), "../fixtures/test_git_repo")

    # Ensure we start fresh
    delete_repo(@@test_repo_name)
    create_repo(@@test_repo_name, @@test_repo_url)
  end

  teardown_once do
    delete_repo(@@test_repo_name)
  end

  should "delete an existing repository from the database and the filesystem" do
    assert GitRepo.first(:name => @@test_repo_name), "#{@@test_repo_name} does not exist in the database"
    assert File.exists?(repo_path(@@test_repo_name)), "#{@@test_repo_name} does not exist on the filesystem"

    DeleteRepo.perform(@@test_repo_name)

    assert GitRepo.first(:name => @@test_repo_name).nil?, "#{@@test_repo_name} still exists in the database"
    refute File.exists?(repo_path(@@test_repo_name)), "#{@@test_repo_name} still exists in the filesystem"
  end

  def repo_path(repo_name) File.join(REPOS_ROOT, @@test_repo_name) end
  def delete_repo(repo_name)
    repo = GitRepo.first(:name => repo_name)
    repo.destroy if repo
    FileUtils.rm_rf(repo_path(repo_name)) if File.exists?(repo_path(repo_name))
  end
  def create_repo(repo_name, repo_url)
    CloneNewRepo.perform(repo_name, repo_url)
    GitRepo.create(:name => repo_name, :path => repo_path(repo_name))
  end
end

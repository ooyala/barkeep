require "lib/script_environment"
require "minitest/autorun"
require "scope"

# The fixtures directory contains test git repos. Use when you cannot stub a fake Git repo.
FIXTURES_PATH ||= File.join(File.dirname(__FILE__), "/fixtures")
TEST_REPO_NAME ||= "test_git_repo"


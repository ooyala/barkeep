require "lib/script_environment"
require "minitest/autorun"
require "scope"

# The fixtures directory contains test git repos. Use when you cannot stub a fake Git repo.
FIXTURES_PATH ||= File.join(File.dirname(__FILE__), "/fixtures")
TEST_REPO_NAME ||= "test_git_repo"

# A helper method to allow stubbing out multiple properties (to static values) at once by passing in the
# object and a hash of { <method name symbol>, <value> }.
def stub_many(object, stubs)
  stubs.each { |name, value| stub(object).method_missing(name, &Proc.new { value }) }
end

ENV["RACK_ENV"] = "test"

require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "minitest/autorun"
require "scope"
require "rack/test"
require "rr"
require "nokogiri"

require "test/stub_helper"

# Fixtuers contains test git repos. Use when you cannot stub fake a Git repo.
FIXTURES_PATH = File.join(File.dirname(__FILE__), "/fixtures")
TEST_REPO_NAME = "test_git_repo"

module Scope
  class TestCase
    include RR::Adapters::MiniTest

    def assert_status(status_code) assert_equal status_code, last_response.status end
    def dom_response
      @dom_response ||= Nokogiri::HTML(last_response.body)
    end
  end
end
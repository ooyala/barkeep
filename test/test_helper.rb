ENV["RACK_ENV"] = "test"

require "bundler/setup"
require "pathological"
require "lib/script_environment"

require "minitest/autorun"
require "scope"
require "rack/test"
require "rr"

require "test/stub_helper"

module Scope
  class TestCase
    include RR::Adapters::MiniTest
  end
end
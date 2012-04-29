ENV["RACK_ENV"] = "test"
require "bundler/setup"
require "pathological"
require "test/test_helper"
require "rack/test"
require "rr"
require "nokogiri"
require "test/stub_helper"

module Scope
  class TestCase
    include RR::Adapters::MiniTest

    def assert_status(status_code) assert_equal status_code, last_response.status end
    def dom_response
      @dom_response ||= Nokogiri::HTML(last_response.body)
    end
  end
end
require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "lib/emails"
require "lib/git_helper"
require "ostruct"
require "nokogiri"

class BackgroundJobsTest < Scope::TestCase
  context "fork_child_process" do
    should "fork a child process and return its pid" do
      child_pid = BackgroundJobs.fork_child_process { exit 123 }
      Process.wait(child_pid) # This will block until the child is done.
      assert 123, $?
    end
  end

  context "run_process_with_timeout" do
    should "raise a Timeout::Error when the process takes too long" do
      raised_error = nil
      begin
        BackgroundJobs.run_process_with_timeout(0) { 1 + 2 + 3 }
      rescue Timeout::Error => error
        raised_error = error
      end
      assert_equal false, raised_error.nil?
    end
  end
end
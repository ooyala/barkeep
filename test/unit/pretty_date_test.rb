require File.expand_path(File.join(File.dirname(__FILE__), "../unit_test_helper.rb"))

require "lib/pretty_date"

class PrettyDateTest < Scope::TestCase
  context "to_pretty" do
    setup do
      @now = Time.utc(2011, 8, 15, 12, 0) # 2011-08-15 12:00:00 UTC
      stub(Time).now { @now }
      @second = 1
      @minute = 60 * @second
      @hour = 60 * @minute
      @day = 24 * @hour
      @year = 365 * @day
    end

    should "give reasonable 'seconds ago' representations" do
      assert_equal "just now", time_ago(0)
      assert_equal "a second ago", time_ago(1 * @second)
      assert_equal "30 seconds ago", time_ago(30 * @second)
      assert_equal "59 seconds ago", time_ago(59 * @second)
    end

    should "give reasonable 'minutes ago' representations" do
      assert_equal "a minute ago", time_ago(1 * @minute + 29 * @second)
      assert_equal "2 minutes ago", time_ago(1 * @minute + 30 * @second)
      assert_equal "5 minutes ago", time_ago(5 * @minute)
      assert_equal "59 minutes ago", time_ago(59 * @minute + 29 * @second)
    end

    should "give reasonable 'hours ago' representations" do
      assert_equal "an hour ago", time_ago(59 * @minute + 30 * @second)
      assert_equal "an hour ago", time_ago(1 * @hour + 29 * @minute)
      assert_equal "2 hours ago", time_ago(1 * @hour + 31 * @minute)
      assert_equal "10 hours ago", time_ago(10 * @hour)
      assert_equal "23 hours ago", time_ago(23 * @hour + 29 * @minute)
    end

    should "give reasonable 'days ago' representations" do
      assert_equal "a day ago", time_ago(23 * @hour + 30 * @minute)
      assert_equal "a day ago", time_ago(30 * @hour)
      assert_equal "2 days ago", time_ago(44 * @hour)
      assert_equal "6 days ago", time_ago(6 * @day)
    end

    should "give reasonable representations for times long ago" do
      assert_equal "Aug 08, 2011", time_ago(7 * @day)
      assert_equal "Aug 15, 2010", time_ago(1 * @year)
    end
  end

  def time_ago(interval)
    (@now - interval).to_pretty
  end
end

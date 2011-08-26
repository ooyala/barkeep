require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "lib/emails"
require "lib/git_helper"
require "ostruct"
require "nokogiri"

class SavedSearchTest < Scope::TestCase
  context "titles" do
    should "generate a title for all commits" do
      assert_equal "All commits", SavedSearch.new.title
    end

    should "generate a title for commits by an author" do
      assert_equal "Commits by dmac and philc", SavedSearch.new(:authors => "dmac,  philc").title
    end

    should "generate a title for commits by an author in a repo" do
      assert_equal "Commits by kle in the barkeep repo",
          SavedSearch.new(:authors => "kle", :repos => "barkeep").title
    end
  end
end

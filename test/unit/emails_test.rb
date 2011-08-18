require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "lib/emails"
require "lib/git_helper"
require "ostruct"

class EmailsTest < Scope::TestCase
  context "strip_unchanged_blank_lines" do
    should "remove unchanged blank lines from both sides of the array" do
      line_diffs = [
        LineDiff.new(:same, "   ", nil, 0, 0),
        LineDiff.new(:added, "   ", nil, 0, 0),
        LineDiff.new(:same, "", nil, 0, 0)]
      assert_equal [line_diffs[1]], Emails.strip_unchanged_blank_lines(line_diffs)
    end
  end

  context "email body" do
    setup do
      @general_comment = Comment.new(:text => "my general comment")
      user = User.new(:name => "jimbo")
      @general_comment.stubs(:user).returns(user)
      @grit_commit = OpenStruct.new(:short_message => "message", :id_abbrev => "commit_id",
          :author => "commit_author", :date => Time.now)
      GitHelper.stubs(:get_tagged_commit_diffs).returns([])
    end

    should "include general comments when there are some" do
      email = Emails.comment_email_body(@grit_commit, [@general_comment])
      assert email.include?("General comments")
    end

    should "omit general comments when there are none" do
      email = Emails.comment_email_body(@grit_commit, [])
      assert_equal false, email.include?("General comments")
    end

    should "include line comments when there are some" do
      # TODO(philc):
    end
  end
end

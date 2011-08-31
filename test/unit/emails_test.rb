require File.expand_path(File.join(File.dirname(__FILE__), "../test_helper.rb"))
require "lib/emails"
require "lib/git_helper"
require "ostruct"
require "nokogiri"

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
      @commit = Commit.new
      grit_commit = OpenStruct.new(
          :short_message => "message", :id_abbrev => "commit_id",
          :author => "commit_author", :date => Time.now)
      stub(@commit).grit_commit { grit_commit }
      stub(@commit).git_repo { GitRepo.new(:name => "my_repo") }
      stub(GitHelper).get_tagged_commit_diffs { [] }
      @user = User.new(:name => "jimbo")
    end

    context "general comments" do
      setup do
        @general_comment = Comment.new(:text => "my general comment")
        stub(@general_comment).user { @user }
      end

      should "include general comments when there are some" do
        email = Emails.comment_email_body(@commit, [@general_comment])
        assert email.include?("General comments")
      end

      should "omit general comments when there are none" do
        email = Emails.comment_email_body(@commit, [])
        refute email.include?("General comments")
      end
    end

    context "line comments" do
      setup do
        @commit_file = CommitFile.new(:filename => "file.txt")
        @commit_file.id = 12
        @line_comment = Comment.new(:text => "my line comment", :line_number => 1,
            :commit_file_id => @commit_file.id)
        stub(@line_comment).commit_file { @commit_file }
        stub(@line_comment).user { @user }
      end

      should "trim out whitespace that's common to all lines of the diff" do
        stub(GitHelper).get_tagged_commit_diffs { diffs_with_lines(@commit_file, ["  Line 1", "    Line 2"]) }
        email = Nokogiri::HTML(Emails.comment_email_body(@commit, [@line_comment]))
        diff_lines = email.css("pre").text.split("\n")[0..1]
        # Both lines had two leading spaces in common. The email should have factored those out.
        assert_equal ["+Line 1", "+  Line 2"], diff_lines
      end
    end
  end

  # A helper for creating test data
  def diffs_with_lines(commit_file, lines)
    [{
      :file_name_after => commit_file.filename,
      :lines => lines.each_with_index.map { |line, index| LineDiff.new(:added, line, nil, index, index) }
    }]
  end
end

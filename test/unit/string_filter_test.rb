require File.expand_path(File.join(File.dirname(__FILE__), "../unit_test_helper.rb"))
require "lib/string_filter"
require "lib/filters"
require "dedent"

class StringFilterTest < Scope::TestCase
  context "filters" do
    setup do
      @sha = "46b37313bab07c3528e75a2acaf2ca36e44b18f1"
      stub(GitRepo).[](anything) { GitRepo.new }
      stub(Commit).prefix_match do |repo_name, sha, zero_ok, mult_ok|
        @sha.start_with?(sha) ? Commit.new(:sha => @sha) : nil
      end
    end

    should "render markdown" do
      filtered = StringFilter.markdown("[text](http://example.com)")
      assert filtered.include?("<a href")
    end

    should "replace shas with links" do
      filtered = StringFilter.replace_shas_with_links("Fixed in commit #{@sha}", "test_repo")
      assert_equal "Fixed in commit [#{@sha[0..6]}](/commits/test_repo/#{@sha})", filtered
    end

    should "replace sha prefixes with links" do
      filtered = StringFilter.replace_shas_with_links("Fixed in commit #{@sha[0..6]}", "test_repo")
      assert_equal "Fixed in commit [#{@sha[0..6]}](/commits/test_repo/#{@sha})", filtered
    end

    should "not replace nonexistent shas" do
      bad_sha = "d8b17cd56ed95dbf006c9b1cb78c4da21858e6c9"
      filtered = StringFilter.replace_shas_with_links("Fixed in commit #{bad_sha}", "test_repo")
      assert_equal "Fixed in commit #{bad_sha}", filtered
    end

    should "replace shas prepended with repo: with cross repo links" do
      repo = "foo-bar_90"
      filtered = StringFilter.replace_shas_with_links("Fixed in commit #{repo}:#{@sha}", "test_repo")
      assert_equal "Fixed in commit [#{repo}:#{@sha[0..6]}](/commits/#{repo}/#{@sha})", filtered
    end

    should "link jira issues" do
      ticket = "APP-1234"
      filtered = StringFilter.link_jira_issue("in ticket #{ticket}")
      assert filtered.include?("jira.corp.ooyala.com/browse/#{ticket}")
    end

    should "not link jira issues that do not have a whitelisted group" do
      ticket = "NOTJIRA-1234"
      message = "in ticket #{ticket}"
      filtered = StringFilter.link_jira_issue(message)
      assert_equal message, filtered
    end

    should "link embedded images" do
      image = "![image](http://example.com/image.png)"
      filtered = StringFilter.link_embedded_images(image)
      assert filtered.include?("[#{image}](http://example.com/image.png)")
    end

    should "link github issue" do
      filtered = StringFilter.link_github_issue("issue #42", "ooyala", "test_repo")
      assert filtered.include?("github.com/ooyala/test_repo/issues/42")
    end

    should "convert newlines to html" do
      filtered = StringFilter.newlines_to_html("\n")
      assert filtered.include?("<br/>")
    end

    should "truncate front" do
      long_string = "a" * 20
      assert_equal 10, StringFilter.truncate_front(long_string, 10).length
    end

    should "escape_html" do
      html = "<script>alert('hi')</script>"
      filtered = StringFilter.escape_html(html)
      assert filtered.include?("&lt;")
    end

    context "class filters" do
      context "comments" do
        setup do
          text = <<-EOF.dedent
            Comment comment **comment**.
            Here's an embedded image: ![the_image](http://example.com/image.png)
            Referencing APP-1234
            With a sha #{@sha}.
          EOF
          comment = Comment.new(:text => text)
          commit = Commit.new
          stub(commit).git_repo { stub(GitRepo.new).name { "test_repo" }}
          stub(comment).commit { commit }
          @filtered_comment = comment.filter_text
        end

        should "link embedded images" do
          image_link = "http://example.com/image.png"
          assert @filtered_comment.include?("href=\"#{image_link}\"")
        end

        should "render markdown" do
          assert @filtered_comment.include?("<strong>")
        end

        should "link jira issue" do
          assert @filtered_comment.include?("jira.corp.ooyala.com/browse/APP-1234")
        end

        should "replace shas with links" do
          assert @filtered_comment.include?("/commits/test_repo/#{@sha}")
        end
      end

      context "commit messages" do
        setup do
          message = <<-EOF.dedent
            <script>
            Fixes #42
            APP-1234
            #{@sha}
          EOF
          commit = Commit.new(:message => message)
          stub(commit).git_repo { stub(GitRepo.new).name { "test_repo" }}
          @filtered_message = commit.filter_message
        end

        should "escape html" do
          assert @filtered_message.include?("&lt;")
        end

        should "convert newlines to html" do
          assert @filtered_message.include?("<br/>")
        end

        should "link github issues" do
          assert @filtered_message.include?("github.com/ooyala/test_repo/issues/42")
        end

        should "link jira issues" do
          assert @filtered_message.include?("jira.corp.ooyala.com/browse/APP-1234")
        end

        should "replace shas with links" do
          assert @filtered_message.include?("/commits/test_repo/#{@sha}")
        end
      end
    end
  end
end

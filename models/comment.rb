# A comment in a commit.
# - text
# - line_number
# TODO(philc): What is file_version?
# - file_version

require "lib/string_filter"

class Comment < Sequel::Model
  include StringFilter

  VERSION_BEFORE = "before"
  VERSION_AFTER = "after"

  many_to_one :user
  many_to_one :commit_file
  many_to_one :commit

  add_filter(:text) { |str| StringFilter.link_embedded_images(str) }
  # replace_shas_with_links comes before markdown for simpler regex and to use markdown syntax to
  # generate links.
  add_filter(:text) do |str, comment|
    StringFilter.replace_shas_with_links(str, comment.commit.git_repo.name)
  end
  add_filter(:text) { |str| StringFilter.markdown(str) }
  add_filter(:text) { |str| StringFilter.link_jira_issue(str) }
  add_filter(:text) { |str| StringFilter.emoji(str) }

  # Some comments can be about the entire commit, and not about a specific line in a file.
  def general_comment?() commit_file_id.nil? end

  # True if this comment pertains to a particular file.
  def file_comment?() !commit_file_id.nil? end
end

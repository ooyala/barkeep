# A comment in a commit.
# - text
# - line_number
# TODO(philc): What is file_version?
# - file_version
class Comment < Sequel::Model
  VERSION_BEFORE = "before"
  VERSION_AFTER = "after"

  many_to_one :user
  many_to_one :commit_file
  many_to_one :commit

  # Some comments can be about the entire commit, and not about a specific line in a file.
  def general_comment?() commit_file_id.nil? end

  # True if this comment pertains to a particular file.
  def file_comment?() !commit_file_id.nil? end

  def format
    text.link_embedded_images
        .markdown
        .replace_shas_with_links(commit.git_repo.name)
  end
end

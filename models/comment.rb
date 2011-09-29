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
    Comment::replace_shas_with_links(RedcarpetManager.redcarpet_pygments.render(text))
  end

  def self.replace_shas_with_links(text)
    # We assume the sha is linking to another commit in this repository.
    repo_name = /\/commits\/([^\/]+)\//.match(request.url)[1] rescue ""
    text.gsub(/([a-zA-Z0-9]{40})/) { |sha| "<a href='/commits/#{repo_name}/#{sha}'>#{sha[0..6]}</a>" }
  end
end

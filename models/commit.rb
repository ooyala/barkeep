require "lib/meta_repo"

# Columns:
# - approved_at: when the commit was approved.
# - approved_by_user_id: the most recent user to approve the commit.
class Commit < Sequel::Model
  many_to_one :user
  many_to_one :git_repo
  one_to_many :commit_files
  one_to_many :comments
  many_to_one :approved_by_user, :class => User

  add_association_dependencies :comments => :destroy, :commit_files => :delete

  def grit_commit
    @grit_commit ||= MetaRepo.instance.grit_commit(git_repo_id, sha)
  end

  def comments
    comments_dataset.filter(:commit_id => id, :line_number => nil).order(:created_at).all
  end

  # Total comments of all types pertaining to this commit (line comments + commit comments)
  def comment_count
    comments_dataset.filter(:commit_id => id).order(:created_at).count
  end

  def approved?() !approved_by_user_id.nil? end

  def approve(user)
    self.approved_at = Time.now
    self.approved_by_user_id = user.id
    save
  end

  def disapprove
    self.approved_at = nil
    self.approved_by_user_id = nil
    save
  end

  def format_message
    message.escape_html
           .newlines_to_html
           .link_github_issue("ooyala", git_repo.name)
           .link_jira_issue
  end
end

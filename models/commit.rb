require "lib/meta_repo"
require "lib/string_filter"

# Columns:
# - approved_at: when the commit was approved.
# - approved_by_user_id: the most recent user to approve the commit.
class Commit < Sequel::Model
  include StringFilter

  many_to_one :git_repo
  one_to_many :commit_files
  one_to_many :comments
  many_to_one :approved_by_user, :class => User

  add_association_dependencies :comments => :destroy, :commit_files => :destroy

  add_filter(:message) { |message| StringFilter.escape_html(message) }
  add_filter(:message) do |message, commit|
    StringFilter.replace_shas_with_links(message, commit.git_repo.name, :skip_markdown => true)
  end
  add_filter(:message) { |message| StringFilter.newlines_to_html(message) }
  add_filter(:message) do |message, commit|
    StringFilter.link_github_issue(message, "ooyala", commit.git_repo.name)
  end
  add_filter(:message) { |message| StringFilter.link_jira_issue(message) }
  add_filter(:message) { |message| StringFilter.emoji(message) }

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

  # Attempt to prefix-match a SHA
  def self.prefix_match(git_repo, partial_sha, zero_commits_ok = false)
    raise "No such repository: #{git_repo}" unless GitRepo[:name => git_repo]
    commits = Commit.join(:git_repos, :id => :git_repo_id).
                     filter(:git_repos__name => git_repo).
                     filter(:sha.like("#{partial_sha}%")).
                     select_all(:commits).limit(2).all
    raise "Ambiguous commit in #{git_repo}: #{partial_sha}" if commits.size > 1
    if commits.empty?
      raise "No such commit in #{git_repo}: #{partial_sha}" unless zero_commits_ok
      nil
    else
      commits[0]
    end
  end
end

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
  one_to_many :review_request

  # This is really one_to_one, but Sequel requires the table containing the foreign key to be many_to_one.
  many_to_one :author

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

  def self.create_review_list_entries(commits)
    comments = Hash.new { |hash, key| hash[key] = [] }
    commits.each do |commit|
      comments[commit[:id]] << Comment[commit[:comment_id]]
    end

    entries = []
    commit_processed = {}
    commits.each do |commit|
      next if commit_processed[commit[:id]]
      commit_processed[commit[:id]] = true
      grit_commit = MetaRepo.instance.grit_commit(commit[:name], commit[:sha])
      next unless grit_commit
      entry = ReviewListEntry.new(grit_commit)
      entry.comments = comments[commit[:id]]
      entries << entry
    end
    entries
  end

  def self.commits_with_recently_resolved_comments(email)
    commits = Commit.select(:commits__id, :git_repo_id, :sha).
        join(:comments, :commit_id => :id).
        join(:authors, :id => :commits__author_id).
        join(:users, :id => :comments__user_id).
        filter(:authors__email => email).
        exclude(:comments__resolved_at => nil).
        exclude(:users__email => email).
        group_by(:commits__id).
        reverse_order(:resolved_at).limit(5).all
    create_review_list_entries(commits)
  end

  # Selects for the given user all the commits with "actionable" comments, that is, comments that
  # are New and for user, or Resolved and from user.
  def self.commits_with_actionable_comments(user_id)
    # The SQL query selects comments that match the following conditions:
    #  1. Comments that have "action_required" and are not closed, and
    #  2a. Comments that were made on one of this user's commits (including any comments by this user),
    #      and are not resolved (and not closed), or
    #  2b. Comments that this user made on some commit that are resolved (but not closed).
    commits = Commit.select(:commits__id, :git_repos__name, :sha, :comments__id___comment_id).
        join(:comments, :commit_id => :id).
        join(:authors, :id => :commits__author_id).
        join(:git_repos, :id => :commits__git_repo_id).
        filter(:action_required => true, :comments__closed_at => nil).
        where({ :authors__user_id => user_id, :comments__resolved_at => nil } |
              { :comments__user_id => user_id } & ~{ :comments__resolved_at => nil }).all
    create_review_list_entries(commits)
  end

  # Selects for the given user all the commits with comments waiting on someone else's action,
  # that is, comments that are New and from user, or Resolved and for user.
  def self.commits_with_pending_comments(user_id)
    # The SQL query selects comments that match the following conditions:
    #  1. Comments that have "action_required" and are not closed, and
    #  2a. Comments that were made on one of this user's commits (including any comments by this user),
    #      and are resolved, or
    #  2b. Comments that this user made on some commit that are new.
    commits = Commit.select(:commits__id, :git_repos__name, :sha, :comments__id___comment_id).
        join(:comments, :commit_id => :id).
        join(:authors, :id => :commits__author_id).
        join(:git_repos, :id => :commits__git_repo_id).
        filter(:action_required => true, :comments__closed_at => nil).
        where({ :comments__user_id => user_id, :comments__resolved_at => nil } |
              { :authors__user_id => user_id } & ~{ :comments__resolved_at => nil }).all
    create_review_list_entries(commits)
  end

  # Selects for the given user all the commits with closed comments related to the given user,
  # that is, comments that are Closed and from user, or Closed and for user.
  def self.commits_with_closed_comments(user_id)
    # The SQL query selects comments that match the following conditions:
    #  1. Comments that have "action_required" and are closed, and
    #  2a. Comments that were made on one of this user's commits (including any comments by this user),
    #      or
    #  2b. Comments that this user made on some commit.
    commits = Commit.select(:commits__id, :git_repos__name, :sha, :comments__id___comment_id).
        join(:comments, :commit_id => :id).
        join(:authors, :id => :commits__author_id).
        join(:git_repos, :id => :commits__git_repo_id).
        filter(:action_required => true).
        where( ~{ :comments__closed_at => nil } &
              ({ :comments__user_id => user_id } | { :authors__user_id => user_id })).all
    create_review_list_entries(commits)
  end
end

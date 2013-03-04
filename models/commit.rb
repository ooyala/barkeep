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

  PAGE_SIZE = 8

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

  def self.opposite_sort_order(order)
    (order == :asc) ? :desc : :asc
  end

  def self.fetch_paged_rows(args)
    dataset = args[:dataset]
    major_col = args[:major_col]
    minor_col = args[:minor_col]
    major_sort = args[:major_sort]
    minor_sort = args[:minor_sort]
    major_op = args[:major_op]
    minor_op = args[:minor_op]
    values = args[:values]
    page_size = args[:page_size]
    if major_col != minor_col
      if values[1].to_s != "0"
        conditions = "#{major_col} #{major_op} ? or (#{major_col} = ? and #{minor_col} #{minor_op} ?)"
        dataset = dataset.filter(conditions, values[1], values[1], values[0])
      end
      dataset = dataset.order(Sequel.send(major_sort, major_col)).
          order_append(Sequel.send(minor_sort, minor_col))
    else
      dataset = dataset.filter("? #{minor_op} ?", minor_col, values[0]).
          order(Sequel.send(minor_sort, minor_col))
    end
    rows = dataset.limit(page_size).all
  end

  def self.paginate_dataset(dataset, page_by_cols, token, direction, page_size)
    page_number, from_values, to_values, is_partial = ReviewList.parse_token(token)
    if page_by_cols.length != from_values.length || page_by_cols.length != to_values.length
      raise ArgumentError.new "page_by_cols.length (#{page_by_cols.length}) does not match token"
    end
    major_col, minor_col = page_by_cols
    major_col, major_sort = Array(major_col)
    minor_col = major_col if minor_col.nil?
    major_sort = :asc if major_sort.nil?
    minor_sort = :asc
    args = { :dataset => dataset, :major_col => major_col, :minor_col => minor_col,
        :major_sort => major_sort, :minor_sort => minor_sort, :page_size => page_size }
    if direction == "next"
      if is_partial
        args[:major_op] = :<
        args[:minor_op] = :>=
        args[:values] = from_values
      else
        args[:major_op] = :<
        args[:minor_op] = :>
        args[:values] = to_values
        page_number += 1
      end
      rows = fetch_paged_rows(args)

      if rows.empty?
        page_number -= 1
        # There is no "next" page, so refill the current page, searching backwards from the
        # last commit id on this page.
        # This also covers the case where there was a partial page but it is now empty.
        args[:major_op] = :>
        args[:minor_op] = :<=
        args[:values] = to_values
        args[:major_sort] = opposite_sort_order(major_sort)
        args[:minor_sort] = opposite_sort_order(minor_sort)
        rows = fetch_paged_rows(args)
        rows.reverse!
      end
    else
      args[:major_sort] = opposite_sort_order(major_sort)
      args[:minor_sort] = opposite_sort_order(minor_sort)
      args[:major_op] = :>
      args[:minor_op] = :<
      args[:values] = from_values
      rows = fetch_paged_rows(args)

      if rows.length < page_size
        # There is no "prev" page or the prev page was not full, so reset the page number to 1, and
        # refill it from the beginning.
        args[:major_sort] = major_sort
        args[:minor_sort] = minor_sort
        args[:major_op] = :>
        args[:minor_op] = :>
        args[:values] = [0, 0]
        rows = fetch_paged_rows(args)
        page_number = 1
      else
        rows.reverse!
        page_number -= 1
        page_number = 1 if page_number < 1
      end
    end
    if rows.empty?
      is_partial = false
      from_values = [0, 0]
      to_values = [0, 0]
    else
      is_partial = rows.length < page_size
      # Strip off the table name, if any
      major_col = major_col.to_s.split("__").last.to_sym
      minor_col = minor_col.to_s.split("__").last.to_sym
      if major_col == minor_col
        from_values = [rows.first[minor_col]]
        to_values = [rows.last[minor_col]]
      else
        from_values = [rows.first[minor_col], rows.first[major_col]]
        to_values = [rows.last[minor_col], rows.last[major_col]]
      end
    end
    token = ReviewList.make_token(page_number, from_values, to_values, is_partial)
    [rows, token]
  end

  # Selects for the given user the commits with "actionable" comments, that is, comments that
  # are New and for user, or Resolved and from user.
  def self.commits_with_actionable_comments(user_id, token = nil, direction = "next", page_size = PAGE_SIZE)
    # The SQL query selects comments that match the following conditions:
    #  1. Comments that have "action_required" and are not closed, and
    #  2a. Comments that were made on one of this user's commits (including any comments by this user),
    #      and are not resolved (and not closed), or
    #  2b. Comments that this user made on some commit that are resolved (but not closed).
    token = ReviewList.make_token(0, 0, 0, false) if token.nil?
    dataset = Commit.select(:commits__id, :git_repos__name, :sha, :authors__user_id___authors_user_id).
        join(:comments, :commit_id => :id).
        join(:authors, :id => :commits__author_id).
        join(:git_repos, :id => :commits__git_repo_id).
        filter(:action_required => true, :comments__closed_at => nil).
        where({ :authors__user_id => user_id, :comments__resolved_at => nil } |
              { :comments__user_id => user_id } & ~{ :comments__resolved_at => nil }).
        group_by(:commits__id)

    commits, token = paginate_dataset(dataset, [:commits__id], token, direction, page_size)
    entries = []
    commits.each do |commit|
      grit_commit = MetaRepo.instance.grit_commit(commit[:name], commit[:sha])
      next unless grit_commit
      if commit[:authors_user_id] == user_id
        comments = Comment.filter(:commit_id => commit[:id]).
            filter(:action_required => true, :comments__closed_at => nil).
            where({ :comments__resolved_at => nil } | { :comments__user_id => user_id }).all
      else
        comments = Comment.filter(:commit_id => commit[:id]).
            filter(:action_required => true, :comments__closed_at => nil).
            where({ :comments__user_id => user_id } & ~{ :comments__resolved_at => nil }).all
      end
      entry = ReviewListEntry.new(grit_commit)
      entry.comments = comments
      entries << entry
    end
    ReviewList.new(entries, token)
  end

  # Selects for the given user all the commits with comments waiting on someone else's action,
  # that is, comments that are New and from user, or Resolved and for user.
  def self.commits_with_pending_comments(user_id, token = nil, direction = "next", page_size = PAGE_SIZE)
    # The SQL query selects comments that match the following conditions:
    #  1. Comments that have "action_required" and are not closed, and
    #  2a. Comments that were made on one of this user's commits (including any comments by this user),
    #      and are resolved, or
    #  2b. Comments that this user made on some commit that are new.
    token = ReviewList.make_token(0, 0, 0, false) if token.nil?
    dataset = Commit.select(:commits__id, :git_repos__name, :sha, :authors__user_id___authors_user_id).
        join(:comments, :commit_id => :id).
        join(:authors, :id => :commits__author_id).
        join(:git_repos, :id => :commits__git_repo_id).
        filter(:action_required => true, :comments__closed_at => nil).
        where({ :comments__user_id => user_id, :comments__resolved_at => nil } |
              { :authors__user_id => user_id } & ~{ :comments__resolved_at => nil }).
        group_by(:commits__id)

    commits, token = paginate_dataset(dataset, [:commits__id], token, direction, page_size)
    entries = []
    commits.each do |commit|
      grit_commit = MetaRepo.instance.grit_commit(commit[:name], commit[:sha])
      next unless grit_commit
      if commit[:authors_user_id] == user_id
        comments = Comment.filter(:commit_id => commit[:id]).
            filter(:action_required => true, :comments__closed_at => nil).
            where(~{ :comments__user_id => user_id } & ~{ :comments__resolved_at => nil }).all
      else
        comments = Comment.filter(:commit_id => commit[:id]).
            filter(:action_required => true, :comments__closed_at => nil).
            filter(:comments__resolved_at => nil, :comments__user_id => user_id).all
      end
      entry = ReviewListEntry.new(grit_commit)
      entry.comments = comments
      entries << entry
    end
    ReviewList.new(entries, token)
  end

  # Selects for the given user all the commits with closed comments related to the given user,
  # that is, comments that are Closed and from user, or Closed and for user.
  def self.commits_with_closed_comments(user_id, token = nil, direction = "next", page_size = PAGE_SIZE)
    # The SQL query selects comments that match the following conditions:
    #  1. Comments that have "action_required" and are closed, and
    #  2a. Comments that were made on one of this user's commits (including any comments by this user),
    #      or
    #  2b. Comments that this user made on some commit.
    token = ReviewList.make_token(0, 0, 0, false) if token.nil?
    dataset = Commit.select(:commits__id, :git_repos__name, :sha, :comments__id___comment_id).
        join(:comments, :commit_id => :id).
        join(:authors, :id => :commits__author_id).
        join(:git_repos, :id => :commits__git_repo_id).
        filter(:action_required => true).
        where( ~{ :comments__closed_at => nil } &
              ({ :comments__user_id => user_id } | { :authors__user_id => user_id })).
        group_by(:commits__id)

    commits, token = paginate_dataset(dataset, [:commits__id], token, direction, page_size)
    entries = []
    commits.each do |commit|
      grit_commit = MetaRepo.instance.grit_commit(commit[:name], commit[:sha])
      next unless grit_commit
      if commit[:authors_user_id] == user_id
        comments = Comment.filter(:commit_id => commit[:id]).
            filter(:action_required => true).
            where(~{ :comments__closed_at => nil }).all
      else
        comments = Comment.filter(:commit_id => commit[:id]).
            filter(:action_required => true).
            where(~{ :comments__closed_at => nil } & { :comments__user_id => user_id }).all
      end
      entry = ReviewListEntry.new(grit_commit)
      entry.comments = comments
      entries << entry
    end
    ReviewList.new(entries, token)
  end
end

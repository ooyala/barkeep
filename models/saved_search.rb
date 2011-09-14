# A saved search represents a list of commits, some read and some unread.
class SavedSearch < Sequel::Model
  many_to_one :user

  PAGE_SIZE = 10

  # The list of commits this saved search represents.
  def commits(token = nil, direction = "before")
    result = MetaRepo.instance.find_commits(
      :repos => repos_list,
      :branches => branches_list,
      :authors => authors_list,
      :paths => paths_list,
      :token => token,
      :direction => direction,
      :commit_filter_proc => self.unapproved_only ? self.method(:select_unapproved_commits).to_proc : nil,
      :limit => PAGE_SIZE)
    page = (result[:count] / PAGE_SIZE).to_i + 1
    [result[:commits], page, result[:tokens]]
  end

  # True if this saved search's results include this commit.
  # NOTE(philc): This ignores the "unapproved_only" option of saved searches, because it's currently
  # being used to compute who to send comment emails to, and those computations should not care if a commit
  # has been approved yet.
  def matches_commit?(commit)
    MetaRepo.instance.search_options_match_commit?(commit.git_repo.name, commit.sha,
        :authors => authors_list,
        :paths => paths_list,
        :branches => branches_list,
        :repos => repos_list)
  end

  # Generates a human readable title based on the search criteria.
  def title
    return "All commits" if [repos, branches, authors, paths, messages].all?(&:nil?)
    if !repos.nil? && [authors, paths, messages].all?(&:nil?)
      return "All commits for the #{comma_separated_list(repos_list)} " +
          "#{english_quantity("repo", repos_list.size)}"
    end

    message = ["Commits"]
    author_list = self.authors_list
    message << "by #{comma_separated_list(authors_list)}" unless authors_list.empty?
    message << "in #{comma_separated_list(paths_list)}" unless paths_list.empty?
    message << "on #{comma_separated_list(branches_list)}" unless branches_list.empty?
    unless repos_list.empty?
      message << "in the #{comma_separated_list(repos_list)} #{english_quantity("repo", repos_list.size)}"
    end
    message.join(" ")
  end

  def authors_list() (self.authors || "").split(",").map(&:strip) end
  def repos_list() (self.repos || "").split(",").map(&:strip) end

  def paths_list
    return [] unless self.paths && !self.paths.empty?
    JSON.parse(self.paths).map(&:strip)
  rescue []
  end

  def branches_list
    return "" unless self.branches
    self.branches.split(",").map(&:strip)
  end

  def self.create_from_search_string(search_string)
    parts = search_string.split(" ")
  end

  private

  # This is used as a commit filter when fetching the commits which make up this saved search.
  def select_unapproved_commits(grit_commits)
    return [] if grit_commits.empty?
    repo = GitRepo.first(:name => grit_commits.first.repo_name)
    raise "This commit does not have a repo_name set on it: #{grit_commits.first.sha}" unless repo
    # Note that the original order of commits should be preserved.
    commits_dataset = Commit.select(:sha).
        filter(:sha => grit_commits.map(&:sha), :git_repo_id => repo.id, :approved_by_user_id => nil)
    commit_ids = Set.new(commits_dataset.all.map(&:sha))
    grit_commits.select { |grit_commit| commit_ids.include?(grit_commit.sha) }
  end

  def english_quantity(word, quantity) quantity == 1 ? word : word + "s" end

  def comma_separated_list(list)
    case list.size
    when 0 then ""
    when 1 then list[0]
    when 2 then "#{list[0]} and #{list[1]}"
    else "#{list[0..-2].join(", ")}, and #{list[-1]}"
    end
  end
end

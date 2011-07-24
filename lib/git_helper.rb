# Helper methods used to retrieve information from a Grit repository needed for the view.
class GitHelper
  MAX_SEARCH_DEPTH = 1_000

  # A list of commits matching any one of the given authors in reverse chronological order.
  def self.commits_by_authors(repo, authors, count)
    # TODO(philc): We should use Grit's paging API here.
    commits = repo.commits("master", MAX_SEARCH_DEPTH)
    commits_by_author = []
    commits.each do |commit|
      if authors.find { |author| author_search_matches?(author, commit) }
        commits_by_author.push(commit)
        break if commits_by_author.size >= count
      end
    end
    commits_by_author
  end

  def self.author_search_matches?(author_search, commit)
    # tig seems to do some fuzzy matching here on the commit's author when you search by author.
    # For instance, "phil" matches "Phil Crosby <phil.crosby@gmail.com>".
    commit.author.email.downcase.index(author_search) == 0 ||
    commit.author.to_s.downcase.index(author_search) == 0
  end
end
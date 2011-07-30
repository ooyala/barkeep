# A saved search represents a list of commits, some read and some unread.
class SavedSearch < Sequel::Model
  one_to_many :search_filters
  many_to_one :users

  PAGE_SIZE = 5

  add_association_dependencies :search_filters => :destroy

  # The list of commits this saved search represents.
  def commits(repo, page_number = 0)
    page_number = 0 if page_number < 0
    GitHelper.commits_by_authors(repo, authors, PAGE_SIZE, page_number * PAGE_SIZE)
  end

  def authors
    # TODO(philc): Assuming we have just one search filter active for this search.
    search_filter = self.search_filters.first
    authors = search_filter.filter_value.split(",").map(&:strip)
  end

  # Generates a human readable title based on the search filters defined for this saved search.
  def title
    "Commits by #{authors.join(", ")}"
  end
end

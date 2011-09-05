# A saved search represents a list of commits, some read and some unread.
class SavedSearch < Sequel::Model
  many_to_one :users

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
      :limit => PAGE_SIZE)
    page = (result[:count] / PAGE_SIZE).to_i + 1
    [result[:commits], page, result[:tokens]]
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

  def english_quantity(word, quantity) quantity == 1 ? word : word + "s" end

  def comma_separated_list(list)
    case list.size
    when 0 then ""
    when 1 then list[0]
    when 2 then "#{list[0]} and #{list[1]}"
    else "#{list[0..-1].join(", ")}, and #{list[-1]}"
    end
  end
end

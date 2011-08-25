# A saved search represents a list of commits, some read and some unread.
class SavedSearch < Sequel::Model
  many_to_one :users

  PAGE_SIZE = 5

  # The list of commits this saved search represents
  def commits(timestamp = Time.now, previous = true)
    # TODO(caleb)
    options = {
      :authors => authors
    }
    MetaRepo.find_commits(options, PAGE_SIZE, timestamp, previous)
  end

  # Generates a human readable title based on the search criteria.
  def title
    return "All commits." if [repos, authors, paths, messages].all?(&:nil?)
    if !repos.nil? && [authors, paths, messages].all?(&:nil?)
      return "All commits for the #{comma_separated_list(repos)} repos."
    end
    # TODO(caleb) A sentence like:
    # "Commits in the backlot and ooyala repos by Caleb, Daniel, and Kevin matching the path '.gitignore'
    "repos: #{repos}; authors: #{authors}; paths: #{paths}; messages: #{messages}"
  end

  def self.create_from_search_string(search_string)
    parts = search_string.split(" ")
  end

  private

  def english_quantity(word, quantity) quantity == 1 ? word + "s" : word end

  def comma_separated_list(list)
    case list.size
    when 0 then ""
    when 1 then list[0]
    when 2 then "#{list[0]} and #{list[1]}"
    else "#{list[0..-1].join(", ")}, and #{list[-1]}"
    end
  end
end

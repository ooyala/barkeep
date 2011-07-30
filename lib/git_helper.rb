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

  def self.get_tagged_commit_diffs(commit)

  end

  def self.apply_diff(data, diff)
    data_lines = data.split("\n")
    diff_lines = diff.split("\n")
    tagged_lines = []
    chunk_starts = []
    diff_lines.each_with_index do |line, index|
      match = /^@@ \-(\d+),(\d+) \+\d+,\d+ @@$/.match(line)
      chunk_starts << { :index => index, :line => Integer(match[1]), :length => Integer(match[2]) } if match
    end

    orig_line_number = 0
    diff_line_number = 0
    chunk_starts.each_with_index do |chunk, index|
      if chunk[:line] > orig_line_number
        tagged_lines += data_lines[orig_line_number-1...chunk[:line]-1].map do |data|
          diff_line_number+=1
          orig_line_number+=1
          { :tag => :same, :data => data, :orig_line => orig_line_number, :diff_line => diff_line_number }
        end
      end
      next_chunk_start = chunk_starts[index+1] || diff_lines.count
      (chunk[:index]+1...next_chunk_start).each do |diff_index|
        case diff_lines[diff_index][0]
          when " "
            tag = :same
            diff_line_number+=1
            orig_line_number+=1
          when "+"
            tag = :added
            diff_line_number+=1
          when "-"
            tag = :removed
            orig_line_number+=1
        end
        tagged_lines << { :tag => tag, :data => diff_lines[diff_index][1..-1],
                          :orig_line => orig_line_number, :diff_line => diff_line_number }
      end
    end
    last_chunk = chunk_starts[-1]
    remaining_line_number = last_chunk[:line] + last_chunk[:length]
    if remaining_line_number <= data_lines.count
      tagged_lines += data_lines[remaining_line_number..data_lines.count].map do |data|
        diff_line_number+=1
        orig_line_number+=1
        { :tag => :same, :data => data, :orig_line => orig_line_number, :diff_line => diff_line_number }
      end
    end
    tagged_lines
  end
end

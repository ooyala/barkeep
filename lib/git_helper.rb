require "cgi"
# Helper methods used to retrieve information from a Grit repository needed for the view.
class GitHelper
  MAX_SEARCH_DEPTH = 1_000

  # A list of commits matching any one of the given authors in reverse chronological order.
  def self.commits_by_authors(repo, authors, count, offset = 0)
    # TODO(philc): We should use Grit's paging API here.
    commits = repo.commits("master", MAX_SEARCH_DEPTH)
    commits_by_author = []
    commits.each do |commit|
      if authors.find { |author| author_search_matches?(author, commit) }
        if offset > 0
          offset = offset - 1
        else
          commits_by_author.push(commit)
          break if commits_by_author.size >= count
        end
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

  def self.blob_binary?(blob)
    blob && !blob.data.empty? && blob.data.index("\0")
  end

  def self.get_tagged_commit_diffs(commit)
    commit.diffs.map do |diff|
      data = {
        :file_name_before => diff.a_path,
        :file_name_after => diff.b_path,
      }
      if GitHelper::blob_binary?(diff.a_blob) || GitHelper::blob_binary?(diff.a_blob)
        data[:binary] = true
      else
        data[:lines] = GitHelper::tag_file(diff.a_blob, diff.diff)
      end
      data
    end
  end

  def self.tag_file(file, diff)
    data_lines = file ? file.data.split("\n") : []
    tagged_lines = []
    orig_line, diff_line = 0, 0
    chunks = tag_diff(diff)

    chunks.each do |chunk|
      if (chunk[:orig_line] > orig_line)
        tagged_lines += data_lines[ orig_line...chunk[:orig_line] ].map do |data|
          diff_line += 1
          orig_line += 1
          LineDiff.new(:same, data, orig_line, diff_line)
        end
      end
      tagged_lines += chunk[:tagged_lines]
      orig_line += chunk[:orig_length]
      diff_line += chunk[:diff_length]
    end
    if orig_line <= data_lines.count
      tagged_lines += data_lines[orig_line..data_lines.count].map do |data|
        diff_line += 1
        orig_line += 1
        LineDiff.new(:same, data, orig_line, diff_line )
      end
    end
    tagged_lines
  end

  def self.tag_diff(diff)
    diff_lines = diff_lines = diff.split("\n")
    chunks = []
    chunk = nil
    orig_line = 0
    diff_line = 0

    diff_lines.each do |line|
      match = /^@@ \-(\d+),(\d+) \+(\d+),(\d+) @@$/.match(line)
      if (match)
        orig_line = Integer(match[1]) - 1
        diff_line = Integer(match[3]) - 1
        chunk = { :orig_line => orig_line, :orig_length => Integer(match[2]),
                          :diff_line => diff_line, :diff_length => Integer(match[4]), :tagged_lines => [] }
        chunks << chunk
      elsif (chunk)
        # normal line after the first @@ line (eg: '-<div class="commitSection">')
        case line[0]
          when " "
            tag = :same
            diff_line += 1
            orig_line += 1
          when "+"
            tag = :added
            diff_line += 1
          when "-"
            tag = :removed
            orig_line += 1
        end
        next if tag.nil?
        chunk[:tagged_lines] << LineDiff.new(tag, line[1..-1], tag == :added ? nil : orig_line,
            tag == :removed ? nil : diff_line)
      end
    end
    chunks
  end
end

class LineDiff
  attr_accessor :tag, :data, :line_num_before, :line_num_after
  def initialize(tag, data, line_num_before, line_num_after)
    @tag = tag
    @data = data
    @line_num_before = line_num_before
    @line_num_after = line_num_after
  end

  def formatted
    line = "<pre>#{self.line_tag + CGI::escapeHTML(@data)}</pre>"
    case @tag
    when :removed then line = "<div class='removed'>#{line}</div>"
    when :added then line = "<div class='added'>#{line}</div>"
    end
    return line
  end

  def line_tag
    case @tag
    when :same then " "
    when :removed then "-"
    when :added then "+"
    end
  end
end

require "cgi"
require "albino"
require "grit"

require "lib/albino_filetype"

# Helper methods used to retrieve information from a Grit repository needed for the view.
class GitHelper
  def self.find_commits(repo, options)
    # TODO(caleb): Deal with these filters:
    #   * branches
    #   * authors
    #   * paths
    #   * messages

    # Need extended regexes to get |.
    git_options = { :extended_regexp => true }
    # Assuming authors is a comma-separated list.
    if options[:authors] && !options[:authors].empty?
      git_options[:author] = options[:authors].split(",").map(&:strip).join("|")
    end
    git_args = ["origin/master"]

    # now, assuming options has everything set up correctly for rev-list except for count and timestamp stuff

    # If nil, then we just want the most recent N results (including the most recent).
    inclusive = options[:timestamp].nil?
    options[:timestamp] ||= Time.now.to_i
    if options[:direction] == "before"
      self.find_commits_before(repo, options[:timestamp], options[:count], inclusive, true, git_options,
                               git_args)
    else
      self.find_commits_after(repo, options[:timestamp], options[:count], false, true, git_options, git_args)
    end
  end

  def self.find_commits_before(repo, timestamp, count, inclusive, pad_results, options, args)
    # TODO(caleb) Make sure this works.
    extra_options = {}
    extra_options[:before] = inclusive ? timestamp : timestamp - 1
    extra_options[:max_count] = count
    results = self.rev_list(repo, options.merge(extra_options), args)
    return results unless pad_results
    if results.empty? && !inclusive
      inclusive = true
      extra_options[:before] = timestamp
      results = self.rev_list(repo, options.merge(extra_options), args)
    end
    # We've gone as far back as possible; return the last N resuls.
    if results.size < count
      results = self.find_commits_after(repo, timestamp, count - results.size, !inclusive, false, options,
                                       args) + results
    end
    results
  end

  # TODO(caleb): see if there is a better way to do this -- I think it's fundamentally inefficient, though.
  # (We can still make it less dumb)
  def self.find_commits_after(repo, timestamp, count, inclusive, pad_results, options, args)
    extra_options = {}
    extra_options[:after] = inclusive ? timestamp : timestamp + 1
    # TODO(caleb) page through big chunks of commits at a time here, I think
    extra_options[:max_count] = 10_000
    results = self.rev_list(repo, options.merge(extra_options), args).last(count)
    return results unless pad_results
    if results.empty? && !inclusive
      inclusive = true
      extra_options[:after] = timestamp
      results = self.rev_list(repo, options.merge(extra_options), args).last(count)
    end
    if results.size < count
      results += self.find_commits_before(repo, timestamp, count - results.size, !inclusive, false, options,
                                          args)
    end
    results
  end

  # Take rev-list options directly and return a list of Grit::Commits
  def self.rev_list(repo, options, args)
    Grit::Commit.list_from_string(repo, repo.git.rev_list(options.merge(:pretty => "raw"), *args))
  rescue Grit::GitRuby::Repository::NoSuchShaFound
    []
  end

  # TODO(caleb): We should probably only inspect the first N bytes of the file for nulls to avoid the
  # pathological case. Also, we could explore better heuristics here (e.g. look at newlines or compare the
  # ratio of printable/non-printable characters like git does).
  def self.blob_binary?(blob)
    blob && !blob.data.empty? && blob.data.index("\0")
  end

  # Returns an array of hashes representing the tagged and colorized lines of each file in the diff.
  # Where :binary indicates if the file is binary, otherwise :lines is the output of tag_file
  # returns: [ { :binary, :lines}, ... ]
  # TODO(philc): Make colored diffs optional. Emails do not require them, and generating them is expensive.
  def self.get_tagged_commit_diffs(commit)
    commit.diffs.map do |diff|
      a_path = diff.a_path
      b_path = diff.b_path
      data = {
        :file_name_before => a_path,
        :file_name_after => b_path,
      }
      filetype = AlbinoFiletype::detect_filetype(a_path == "dev/null" ? b_path : a_path)
      if GitHelper::blob_binary?(diff.a_blob) || GitHelper::blob_binary?(diff.b_blob)
        data[:binary] = true
      else
        data[:lines] = GitHelper::tag_file(diff.a_blob, diff.b_blob, diff.diff, filetype)
      end
      data
    end
  end

  def self.colorize_blob(blob, filetype)
    return "" if blob.nil?
    syntaxer = Albino.new(blob.data, filetype, :html)
    syntaxer.colorize({ :O => "nowrap=true,stripnl=false,stripall=false" }).split("\n")
  end

  #parse unified diff and return an array of LineDiff, that has all the lines in the original file and the diffs
  # returns: [ {:tag, :data, :highlighted_data, :line_num_before, :line_num_after}, ... ]
  def self.tag_file(file, file_after, diff, filetype)
    before_lines = file ? file.data.split("\n") : []
    after_lines = file_after ? file_after.data.split("\n") : []
    before_highlighted = GitHelper::colorize_blob(file, filetype)
    after_highlighted = GitHelper::colorize_blob(file_after, filetype)
    tagged_lines = []
    orig_line, diff_line = 0, 0
    chunks = tag_diff(diff, before_highlighted, after_highlighted)

    chunks.each do |chunk|
      if chunk[:orig_line] && chunk[:orig_line] > orig_line
        tagged_lines += before_lines[ orig_line...chunk[:orig_line] ].map do |data|
          diff_line += 1
          orig_line += 1
          LineDiff.new(:same, data, before_highlighted[orig_line-1], orig_line, diff_line)
        end
      end
      tagged_lines += chunk[:tagged_lines]
      orig_line += chunk[:orig_length]
      diff_line += chunk[:diff_length]
    end
    if orig_line <= before_lines.count
      tagged_lines += before_lines[orig_line..before_lines.count].map do |data|
        diff_line += 1
        orig_line += 1
        LineDiff.new(:same, data, before_highlighted[orig_line-1], orig_line, diff_line )
      end
    end
    tagged_lines
  end

  # parses unified diff, into objects so that the rest of the file can be inserted around it.
  # returns { :orig_line, :orig_length, :diff_line, :diff_length, [ DiffLines... ] }
  def self.tag_diff(diff, before_highlighted, after_highlighted)
    diff_lines = diff_lines = diff.split("\n")
    chunks = []
    chunk = nil
    orig_line = 0
    diff_line = 0

    diff_lines.each do |line|
      match = /^@@ \-(\d+),(\d+) \+(\d+),(\d+) @@$/.match(line)
      if match
        orig_line = Integer(match[1]) - 1
        diff_line = Integer(match[3]) - 1
        chunk = { :orig_line => orig_line, :orig_length => Integer(match[2]), :diff_line => diff_line,
            :diff_length => Integer(match[4]), :tagged_lines => [] }
        chunks << chunk
        next
      end
      match_new_file = /^@@ \-(\d+) \+(\d+),(\d+) @@$/.match(line)
      if match_new_file
        orig_line = nil
        diff_line = Integer(match_new_file[2]) - 1
        chunk = { orig_line => nil, :orig_length => 0, :diff_line => diff_line,
            :diff_length => Integer(match_new_file[3]), :tagged_lines => [] }
        chunks << chunk
        next
      end
      match_removed_file = /^@@ \-(\d+),(\d+) \+(\d+) @@$/.match(line)
      if match_removed_file
        orig_line = Integer(match_removed_file[1]) - 1
        diff_line = nil
        chunk = { orig_line => orig_line, :orig_length => Integer(match_removed_file[2]), diff_line => nil,
            :diff_length => 0, :tagged_lines => [] }
        chunks << chunk
        next
      end
      if chunk
        # normal line after the first @@ line (eg: '-<div class="commitSection">')
        case line[0]
          when " "
            tag = :same
            diff_line += 1
            orig_line += 1
            highlighted = before_highlighted[orig_line-1]
          when "+"
            tag = :added
            diff_line += 1
            highlighted = after_highlighted[diff_line-1]
          when "-"
            tag = :removed
            orig_line += 1
            highlighted = before_highlighted[orig_line-1]
        end
        next if tag.nil?
        chunk[:tagged_lines] << LineDiff.new(tag, line[1..-1], highlighted, tag == :added ? nil : orig_line,
            tag == :removed ? nil : diff_line, :chunk => true)
      end
    end
    chunks.each { |chunk| chunk[:tagged_lines][0].chunk_start = true }
    chunks
  end
end

class LineDiff
  attr_accessor :tag, :data, :highlighted_data, :line_num_before, :line_num_after, :chunk, :chunk_start
  def initialize(tag, data, highlighted_data, line_num_before, line_num_after, chunk=false, chunk_start=false)
    @tag = tag
    @data = data
    @highlighted_data = highlighted_data
    @line_num_before = line_num_before
    @line_num_after = line_num_after
    @chunk = chunk
    @chunk_start = chunk_start
  end

  def formatted
    line = "<pre>#{self.line_tag + highlighted_data}</pre>"
    case @tag
    when :removed then line = "<div class='removed'>#{line}</div>"
    when :added then line = "<div class='added'>#{line}</div>"
    when :same then line = "<div class='same'>#{line}</div>"
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

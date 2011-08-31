# TODO(caleb) Test this core logic.

require "cgi"
require "grit"

require "lib/albino_filetype"
require "lib/syntax_highlighter"

# Helper methods used to retrieve information from a Grit repository needed for the view.
class GitHelper
  def self.initialize_git_helper(redis)
    @@syntax_highlighter = SyntaxHighlighter.new(redis)
  end
  # mode = :commits or :count
  # retain = :first or :last
  def self.commits_with_limit(repo, options, args, limit, mode = :commits, retain = :first)
    raise "Control result count with 'limit', not in options" unless (options.keys & [:n, :max_count]).empty?
    if retain == :first || mode == :count
      return self.rev_list(repo, options.merge({ :max_count => limit}), args, mode)
    end
    # Now the tricky part
    # TODO(caleb) Make this marginally smart (not sure how to do this efficiently).
    extra_options = { :max_count => 10_000 }
    self.rev_list(repo, options.merge(extra_options), args, mode).last(limit)
  end

  # Take rev-list options directly and return a list of Grit::Commits or a count
  # If the former, we also tack on the repo name to each commit.
  # This behavior varies from Grit::Git#rev_list in that it doesn't attempt to do any extra parsing for the
  # --all option. We also add the ability to only count result.
  # mode is :commits or :count
  def self.rev_list(repo, options, args, mode = :commits)
    raise "Cannot specify formatting" if options[:pretty] || options[:format]
    count = mode != :commits
    extra_options = count ? { :count => true } : extra_options = { :pretty => "raw" }
    result = repo.git.rev_list(options.merge(extra_options), args)
    return result.to_i if count
    commits = Grit::Commit.list_from_string(repo, result)
    commits.each { |commit| commit.repo_name = repo.name }
    commits
  rescue Grit::GitRuby::Repository::NoSuchShaFound
    mode == :commits ? [] : 0
  end

  # TODO(caleb): We should probably only inspect the first N bytes of the file for nulls to avoid the
  # pathological case. Also, we could explore better heuristics here (e.g. look at newlines or compare the
  # ratio of printable/non-printable characters like git does).
  def self.blob_binary?(blob)
    blob && !blob.data.empty? && blob.data.index("\0")
  end

  # Returns an array of hashes representing the tagged and colorized lines of each file in the diff.
  # Where :binary indicates if the file is binary, otherwise :lines is the output of tag_file
  # options:
  #  use_syntax_highlighting - whether we should use syntax highlighting when generating diffs.
  # returns: [ { :binary, :lines}, ... ]
  # TODO(philc): Make colored diffs optional. Emails do not require them, and generating them is expensive.
  def self.get_tagged_commit_diffs(repo_name, commit, options = {})
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
        if options[:use_syntax_highlighting]
          before = @@syntax_highlighter.colorize_blob(repo_name, filetype, diff.a_blob)
          after = @@syntax_highlighter.colorize_blob(repo_name, filetype, diff.b_blob)
        else
          before = diff.a_blob ? diff.a_blob.data : ""
          after = diff.b_blob ? diff.b_blob.data : ""
        end
        data[:lines] = GitHelper::tag_file(before, after, diff.diff, filetype)
      end
      data
    end
  end

  # Parse unified diff and return an array of LineDiff objects, which have all the lines in the original file
  # as well as the changed (diff) lines.
  def self.tag_file(file_before, file_after, diff, filetype)
    before_lines = file_before ? file_before.split("\n") : []
    after_lines = file_after ? file_after.split("\n") : []
    tagged_lines = []
    orig_line, diff_line = 0, 0
    chunks = tag_diff(diff, before_lines, after_lines)

    chunks.each do |chunk|
      if chunk[:orig_line] && chunk[:orig_line] > orig_line
        tagged_lines += before_lines[orig_line...chunk[:orig_line]].map do |data|
          diff_line += 1
          orig_line += 1
          LineDiff.new(:same, before_lines[orig_line - 1], orig_line, diff_line)
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
        LineDiff.new(:same, before_lines[orig_line-1], orig_line, diff_line )
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
        chunk[:tagged_lines] << LineDiff.new(tag, highlighted, tag == :added ? nil : orig_line,
            tag == :removed ? nil : diff_line, :chunk => true)
      end
    end
    chunks.each { |chunk| chunk[:tagged_lines][0].chunk_start = true }
    chunks
  end
end

class LineDiff
  attr_accessor :tag, :data, :line_num_before, :line_num_after, :chunk, :chunk_start
  def initialize(tag, data, line_num_before, line_num_after, chunk=false, chunk_start=false)
    @tag = tag
    @data = data
    @line_num_before = line_num_before
    @line_num_after = line_num_after
    @chunk = chunk
    @chunk_start = chunk_start
  end

  def formatted
    line = "<pre>#{self.line_prefix + self.data}</pre>"
    case @tag
    when :removed then line = "<div class='removed'>#{line}</div>"
    when :added then line = "<div class='added'>#{line}</div>"
    when :same then line = "<div class='same'>#{line}</div>"
    end
    return line
  end

  def line_prefix
    case @tag
    when :same then " "
    when :removed then "-"
    when :added then "+"
    end
  end
end

# TODO(caleb) Test this core logic.

require "cgi"
require "grit"

require "lib/albino_filetype"
require "lib/syntax_highlighter"

# Helper methods used to retrieve information from a Grit repository needed for the view.
class GitHelper
  @@syntax_highlighter = nil
  def self.initialize_git_helper(redis)
    @@syntax_highlighter = SyntaxHighlighter.new(redis)
  end
  # mode = :commits or :count
  # retain = :first or :last
  def self.commits_with_limit(repo, git_command_options, limit, mode = :commits, retain = :first)
    unless (git_command_options.keys & [:n, :max_count]).empty?
      raise "Control result count with 'limit', not in options"
    end

    if retain == :first || mode == :count
      return self.rev_list(repo, git_command_options.merge({ :max_count => limit}), mode)
    else
      # Now the tricky part
      # TODO(caleb) Make this marginally smart (not sure how to do this efficiently).
      extra_options = { :max_count => 10_000 }
      self.rev_list(repo, git_command_options.merge(extra_options), mode).last(limit)
    end
  end

  # Take rev-list options directly and return a list of Grit::Commits or a count.
  # If the former, we also tack on the repo name to each commit.
  # This behavior varies from Grit::Git#rev_list in that it doesn't attempt to do any extra parsing for the
  # --all option. We also add the ability to only count result.
  # - repo: the Grit repo.
  # - command_options: a hash which includes any CLI options (to be passed through to git rev-list as
  #   --option1, --option2). If this hash contains the key "cli_args", those args will be included after the
  #   options.
  # - mode: :commits or :count.
  def self.rev_list(repo, command_options, mode = :commits)
    raise "Cannot specify formatting" if command_options[:pretty] || command_options[:format]

    command_options = command_options.dup
    count = (mode != :commits)
    extra_options = count ? { :count => true } : extra_options = { :pretty => "raw" }
    args = command_options[:cli_args] || []
    command_options.delete(:cli_args)
    result = repo.git.rev_list(command_options.merge(extra_options), args)
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
  # Where :special_case indicates if the file is an exception of some kind (binary file, corrupt/unparseable
  # file, etc), otherwise :lines and :breaks are the output of tag_file.
  # options:
  #  use_syntax_highlighting - whether we should use syntax highlighting when generating diffs.
  # returns: [ { :binary, :lines, :breaks}, ... ]
  # TODO(philc): Make colored diffs optional. Emails do not require them, and generating them is expensive.
  def self.get_tagged_commit_diffs(repo_name, commit, options = {})
    begin
      commit.diffs.map do |diff|
        a_path = diff.a_path
        b_path = diff.b_path
        data = {
          :file_name_before => a_path,
          :file_name_after => b_path,
        }
        filetype = AlbinoFiletype.detect_filetype(a_path == "dev/null" ? b_path : a_path)
        if GitHelper.blob_binary?(diff.a_blob) || GitHelper.blob_binary?(diff.b_blob)
          data[:special_case] = "This is a binary file."
        else
          if options[:use_syntax_highlighting] || options[:cache_prime]
            begin
              before = @@syntax_highlighter.colorize_blob(repo_name, filetype, diff.a_blob)
              after = @@syntax_highlighter.colorize_blob(repo_name, filetype, diff.b_blob)
            rescue RubyPython::PythonError
              data[:special_case] = "This file contains unexpected characters."
              next data
            end
          else
            # Diffs can be missing a_blob or b_blob if the change is an added or removed file.
            before, after = [diff.a_blob, diff.b_blob].map { |blob| blob ? blob.data : "" }
          end
          unless options[:cache_prime]
            data.merge! GitHelper.tag_file(before, after, diff)
          end
        end
        data
      end
    rescue Grit::Git::GitTimeout => e
      # NOTE/TODO(dmac): Grit will die when trying to diff huge commits.
      # Here we're returning an skeleton diff so we can actually display something in the UI.
      # It's pretty lame, but gets around any exceptions for now.
      [{:file_name_before => "Error processing commit diff",
        :file_name_after => "",
        :special_case => "This commit is too large to process."
      }]
    end
  end

  # Parse unified diff and return an array of LineDiff objects, which have all the lines in the original file
  # as well as the changed (diff) lines.
  def self.tag_file(file_before, file_after, diff)
    before_lines, after_lines = [file_before, file_after].map { |file| file ? file.split("\n",-1) : [] }
    tagged_lines = []
    chunk_breaks = []
    orig_line, diff_line = 0, 0
    chunks = tag_diff(diff, before_lines, after_lines)

    chunks.each_with_index do |chunk, i|
      if chunk.original_line_start && chunk.original_line_start > orig_line
        tagged_lines += before_lines[orig_line...chunk.original_line_start].map do |data|
          diff_line += 1
          orig_line += 1
          LineDiff.new(:same, before_lines[orig_line - 1], orig_line, diff_line)
        end
        chunk_breaks << tagged_lines.size
      end
      tagged_lines += chunk.tagged_lines
      orig_line += chunk.original_lines_changed
      diff_line += chunk.new_lines_changed
    end

    if !before_lines.empty? && orig_line <= before_lines.count
      chunk_breaks << tagged_lines.size
      tagged_lines += before_lines[orig_line..before_lines.count].map do |data|
        diff_line += 1
        orig_line += 1
        LineDiff.new(:same, before_lines[orig_line - 1], orig_line, diff_line )
      end
    end
    { :lines => tagged_lines, :breaks => chunk_breaks }
  end

  # parses unified diff into objects so that the rest of the file can be inserted around it.
  # returns [{ :orig_line, :orig_length, :diff_line, :diff_length, [ DiffLines... ] }, ...]
  def self.tag_diff(diff, before_highlighted, after_highlighted)
    chunks = []
    chunk = nil
    orig_line = 0
    diff_line = 0

    diff.diff.split("\n").each do |line|
      match = /^@@ \-(\d+),(\d+) \+(\d+),(\d+) @@$/.match(line)
      if match
        chunk = PatchChunk.new(match[1].to_i - 1, match[2].to_i, match[3].to_i - 1, match[4].to_i)
        chunks << chunk
        orig_line = chunk.original_line_start
        diff_line = chunk.new_line_start
        next
      end
      match_new_file = /^@@ \-(\d+) \+(\d+),(\d+) @@$/.match(line)
      if match_new_file
        chunk = PatchChunk.new(nil, 0, match_new_file[2].to_i - 1, match_new_file[3].to_i)
        chunks << chunk
        orig_line = chunk.original_line_start
        diff_line = chunk.new_line_start
        next
      end
      match = /^@@ \-(\d+),(\d+) \+(\d+) @@$/.match(line)
      if match
        if diff.deleted_file
          chunk = PatchChunk.new(match[1].to_i - 1, match[2].to_i, nil, 0)
        elsif diff.new_file
          chunk = PatchChunk.new(nil, 0, match[3].to_i - 1, 1)
        end
        chunks << chunk
        orig_line = chunk.original_line_start
        diff_line = chunk.new_line_start
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
        next unless tag
        chunk.tagged_lines << LineDiff.new(tag, highlighted, tag == :added ? nil : orig_line,
            tag == :removed ? nil : diff_line, true)
      end
    end
    chunks.each do |chunk|
      chunk.tagged_lines[0].chunk_start = true
      process_chunk_for_replaced(chunk)
    end
    chunks
  end

  # Process lines in each chunk to work out which lines were replaced, rather than newly added or completely
  # removed. Needed for lining things up in side-by-side view
  # NOTE(bochen): this can be done in the same pass as the lines.each in tag_diff, but the performance gain
  #               is not worth making that code any more complex.
  def self.process_chunk_for_replaced(chunk)
    # index of the start of a block of replaced lines
    block_start = 0
    # change in number of lines, orig_lines - diff_lines, in current block
    block_line_delta = 0
    chunk.tagged_lines.each_with_index do |line, i|
      case line.tag
        when :added
          block_line_delta += 1
        when :removed
          block_line_delta -= 1
        when :same
          unless block_start == i
            # end of a block
            block_length = i - block_start
            num_lines_replaced = (block_length - block_line_delta.abs) / 2
            # mark equal number of added and removed as replaced lines.
            # indexing into the same array that is been interated over should be ok if there is no change in
            # item order
            block = chunk.tagged_lines[block_start...i]
            block.select { |l| l.tag == :added }.take(num_lines_replaced).each { |l| l.replace = true }
            block.select { |l| l.tag == :removed }.take(num_lines_replaced).each { |l| l.replace = true }
            block_line_delta = 0
          end
          # initialize next block assuming its on the next line
          block_start = i + 1
      end
    end
  end
end

class LineDiff
  LINE_PREFIX = {
    :same => " ",
    :removed => "-",
    :added => "+"
  }

  attr_accessor :tag, :data, :line_num_before, :line_num_after, :chunk, :chunk_start, :index, :replace
  def initialize(tag, data, line_num_before, line_num_after, chunk = false, chunk_start = false,
                 replace = false)
    @tag = tag
    @data = data
    @line_num_before = line_num_before
    @line_num_after = line_num_after
    @chunk = chunk
    @chunk_start = chunk_start
    # replaced indicates added lines that replace an existing line, or removed lines that will be replaced
    # useful for lining up the side by side view
    @replace = replace
  end

  def line_prefix() LINE_PREFIX[self.tag] end

  def formatted
    "<div class='#{@tag}'><pre>#{line_prefix + @data}</pre></div>"
  end
end

class PatchChunk
  attr_accessor :original_line_start, :original_lines_changed, :new_line_start, :new_lines_changed,
      :tagged_lines

  def initialize(original_line_start, original_lines_changed, new_line_start, new_lines_changed)
    @original_line_start = original_line_start
    @original_lines_changed = original_lines_changed
    @new_line_start = new_line_start
    @new_lines_changed = new_lines_changed
    @tagged_lines = []
  end

end

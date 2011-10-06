require "lib/git_helper"
require "diff/lcs"
require "diff/lcs/hunk"

# Performs diffs and syntax highlighting for a diff blob.
class GitDiffUtils
  @@syntax_highlighter = nil
  def self.setup(redis)
    @@syntax_highlighter ||= SyntaxHighlighter.new(redis)
  end

  # Returns an array of hashes representing the tagged and colorized lines of each file in the diff.
  # Where :special_case indicates if the file is an exception of some kind (binary file, corrupt/unparseable
  # file, etc), otherwise :lines and :breaks are the output of tag_file.
  # options:
  #  - use_syntax_highlighting: whether we should use syntax highlighting when generating diffs.
  #  - warm_the_cache: true if we're just calling this to warm the cache, which is done as part of the commit
  #    ingestion process. We do less work in this case.
  # returns: [ { :binary, :lines, :breaks}, ... ]
  # TODO(philc): Make colored diffs optional. Emails do not require them, and generating them is expensive.
  def self.get_tagged_commit_diffs(repo_name, commit, options = {})
    repo = MetaRepo.instance.grit_repo_for_name(repo_name)
    begin
      GitDiffUtils.show(repo, commit).map do |diff|
        a_path = diff.a_path
        b_path = diff.b_path
        data = {
          :file_name_before => a_path,
          :file_name_after => b_path,
          :renamed => diff.renamed_file,
          :lines_added => 0,
          :lines_removed => 0,
        }
        filetype = AlbinoFiletype.detect_filetype(a_path == "dev/null" ? b_path : a_path)
        if GitHelper.blob_binary?(diff.a_blob) || GitHelper.blob_binary?(diff.b_blob)
          data[:special_case] = "This is a binary file."
        elsif diff.new_file && diff.diff.empty?
          data[:special_case] = "This is an empty file."
        elsif diff.renamed_file && diff.diff.empty?
          data[:special_case] = "File was renamed, but no other changes were made."
        else
          if options[:use_syntax_highlighting] || options[:warm_the_cache]
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
          raw_diff = GitDiffUtils.diff(diff.a_blob, diff.b_blob)

          data.merge! GitDiffUtils.tag_file(before, after, diff, raw_diff) unless options[:warm_the_cache]
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
  def self.tag_file(file_before, file_after, diff, raw_diff)
    before_lines, after_lines = [file_before, file_after].map { |file| file ? file.split("\n",-1) : [] }
    tagged_lines = []
    chunk_breaks = []
    orig_line, diff_line = 0, 0
    chunks = tag_diff(diff, raw_diff, before_lines, after_lines)

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
    lines_added = tagged_lines.select { |line| line.tag == :added }.count
    lines_removed = tagged_lines.select { |line| line.tag == :removed }.count
    { :lines => tagged_lines, :breaks => chunk_breaks,
        :lines_added => lines_added, :lines_removed => lines_removed }
  end

  # parses unified diff into objects so that the rest of the file can be inserted around it.
  # returns [{ :orig_line, :orig_length, :diff_line, :diff_length, [ DiffLines... ] }, ...]
  def self.tag_diff(diff, raw_diff, before_highlighted, after_highlighted)
    chunks = []
    chunk = nil
    orig_line = 0
    diff_line = 0

    raw_diff.split("\n").each do |line|
      match = /^@@ \-(\d+),(\d+) \+(\d+),(\d+) @@/.match(line)
      # most diffs
      if match
        chunk = PatchChunk.new(match[1].to_i - 1, match[2].to_i, match[3].to_i - 1, match[4].to_i)
        chunks << chunk
        orig_line = chunk.original_line_start
        diff_line = chunk.new_line_start
        next
      end
      # new files, one line deleted files
      match = /^@@ \-(\d+) \+(\d+),(\d+) @@/.match(line)
      if match
        if diff.new_file || (match[1].to_i == 1 && match[2].to_i ==1)
          chunk = PatchChunk.new(nil, 0, match[2].to_i - 1, match[3].to_i)
        elsif match[2].to_i == 0 && match[3].to_i == 0
          chunk = PatchChunk.new(match[1].to_i - 1, 1, nil, 0)
        end
        chunks << chunk
        orig_line = chunk.original_line_start
        diff_line = chunk.new_line_start
        next
      end
      # deleted files, one line new files, and one line additions to empty files
      match = /^@@ \-(\d+),(\d+) \+(\d+) @@/.match(line)
      if match
        if diff.deleted_file
          chunk = PatchChunk.new(match[1].to_i - 1, match[2].to_i, nil, 0)
        elsif match[1].to_i == 0 && match[2].to_i == 0
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

  def self.show(repo, commit)
    if commit.parents.size > 0
      diff = repo.git.native(:diff, {:full_index => true, :find_renames => true}, commit.parents[0].id,
          commit.id)
    else
      diff = repo.git.native(:show, {:full_index => true, :pretty => "raw"}, commit.id)
      if diff =~ /diff --git a/
        diff = diff.sub(/.+?(diff --git a)/m, '\1')
      else
        diff = ""
      end
    end

    Grit::Diff.list_from_string(repo, diff)
  end

  def self.diff(blob_a, blob_b)
    output = ""
    file_length_difference = 0
    context_lines = 3
    data_a, data_b = [blob_a, blob_b].map { |blob| blob ? blob.data.split("\n", -1).map(&:chomp) : [] }
    diffs = Difference::LCS.diff(data_a, data_b)
    return patch if diffs.empty?

    hunk_old = nil
    diffs.each do |piece|
      begin
        hunk = Difference::LCS::Hunk.new(data_a, data_b, piece, context_lines, file_length_difference)
        file_length_difference = hunk.file_length_difference

        next unless hunk_old

        if hunk.overlaps?(hunk_old)
          hunk.unshift(hunk_old)
        else
          output << hunk_old.diff(:unified)
        end
      ensure
        hunk_old = hunk
        output << "\n"
      end
    end

    output << hunk_old.diff(:unified)
    output.lstrip
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

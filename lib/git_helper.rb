# TODO(caleb) Test this core logic.

require "cgi"
require "grit"

require "lib/albino_filetype"
require "lib/syntax_highlighter"

# Helper methods used to retrieve information from a Grit repository needed for the view.
class GitHelper
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
end
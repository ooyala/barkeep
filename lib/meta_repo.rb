# A module that encapsulates operations over a collection of git repositories.
# TODO(caleb): This file has a ton of logic I need to test.
# TODO(caleb): move the code around a bit so this is all a bit more logical and easy to follow. Most of this
# logic should live in files inside lib/commit_search/.

require "bundler/setup"
require "pathological"
require "grit"
require "methodchain"

require "lib/grit_extensions"
require "lib/commit_search/paging_token"
require "lib/git_helper"

class MetaRepo
  # This is the singleton instance that the app and all models use.
  class << self
    attr_reader :instance
    def logger=(logger); @@logger = logger; end
    def configure(logger, repos_root)
      @@logger = logger
      @instance = MetaRepo.new(repos_root)
    end
  end

  attr_reader :repos

  def initialize(repos_root)
    @repos_root = repos_root
    Thread.abort_on_exception = true
    load_repos
  end

  # Loads in any new repos from the repos_root.
  def scan_for_new_repos() load_repos if repos_out_of_date? end

  def load_repos
    @repos = []
    @repo_names_and_ids_to_repos = {}
    @repo_name_to_id = {}

    repo_paths = Dir.glob("#{@repos_root}/*/")

    repo_paths.each do |path|
      path = Pathname.new(path).realpath.to_s # Canonical path
      name = File.basename(path)
      id = GitRepo.find_or_create(:name => name, :path => path).id
      grit_repo = create_grit_repo_for_name(name)
      next unless grit_repo && grit_repo.has_refs?
      @repos << grit_repo
      @repo_name_to_id[name] = id
      @repo_names_and_ids_to_repos[name] = grit_repo
      @repo_names_and_ids_to_repos[id] = grit_repo
    end
  end

  def get_grit_repo(name_or_id) @repo_names_and_ids_to_repos[name_or_id] end

  def db_commit(repo_name, sha)
    Commit[:git_repo_id => @repo_name_to_id[repo_name], :sha => sha]
  end

  # Returns nil if the given commit doesn't exist or is no longer on-disk
  # (because the repo was removed or mistakenly rebased).
  def grit_commit(repo_name_or_id, sha)
    # The grit_repo can be nil if the user has removed the repo from disk.
    grit_repo = get_grit_repo(repo_name_or_id)
    return nil unless grit_repo

    grit_commit = grit_repo.commit(sha)
    return nil unless grit_commit

    grit_commit.repo_name = File.basename(grit_repo.working_dir)
    grit_commit
  end

  # True if the list of commits defined by the search_options will include the given commit sha.
  # - repo_id_or_name: the repo that the commit_sha belongs to.
  # - commit_sha: the sha of the commit, which will be checked against the given search_options.
  # - search_options:
  #   - authors: a list of authors
  #   - repos: a list of repo paths
  #   - branches: a list of branch names
  def search_options_match_commit?(repo_id_or_name, commit_sha, search_options)
    git_command_options = MetaRepo.git_command_options(search_options)
    grit_repo = get_grit_repo(repo_id_or_name)
    grit_commit = grit_repo.commit(commit_sha)

    # Building up this rev-list command is a bit tricky. --all is added to the CL args if we're searching
    # across all branches. --all includes all refs as part of the command, so rev-list will simply return the
    # most recent commits from *any* ref which match the search criteria. What we want to do in that case is
    # limit the time range of the returned commits to match the commit we're looking for. We ask for 10
    # commits and see if the commit we're looking for is in that list, just in case there's more than one
    # commit with the same date (rare).
    # NOTE(philc): min-age and max-age seem to work well as commit filters in all cases. If we ever need
    # to use something more specific when determining if a commit ID is on a branch, we can search with these
    # arguments: git rev-list commit_id^..origin/branch_name --reverse.
    git_command_options[:n] = 10
    git_command_options["min-age"] = git_command_options["max-age"] = grit_commit.date.to_i

    repos = search_options[:repos].blank? ? @repos : repos_which_match(search_options[:repos])

    commit_matches_search = false
    repos.each do |repo|
      commit_ids = GitHelper.rev_list(repo, git_command_options).map(&:sha)
      commit_matches_search = true if commit_ids.include?(grit_commit.sha)
    end

    commit_matches_search
  end

  # Returns a page of commits based on the given options.
  # options:
  #  - authors: a list of authors
  #  - repos: a list of repo paths
  #  - branches: a list of branch names
  #
  # returns: { :commits => [git commits], :count => number of results,
  #            :tokens => { :from => new search token, :to => new search token } }
  def find_commits(search_options)
    raise "Limit required" unless search_options[:limit]

    # Assuming everything has been set up correctly in preparation to invoke git rev-list, add in options for
    # the limit and timestamp.
    token = search_options[:token].then { |token_string| PagingToken.from_s(token_string) }
    commits = (search_options[:direction] == "before") ?
      find_commits_before(search_options, token, token.nil?) :
      find_commits_after(search_options, token, false, true)

    return { :commits => [], :count => 0, :tokens => { :from => nil, :to => nil } } if commits.empty?

    result = { :commits => commits }
    tokens = {}
    [[:from, commits.last], [:to, commits.first]].each do |token_name, commit|
      tokens[token_name] = PagingToken.new(commit.timestamp, commit.repo_name, commit.sha)
    end
    result[:count] = count_commits_to_token(search_options, tokens[:to])
    result[:tokens] = { :from => tokens[:from].to_s, :to => tokens[:to].to_s }
    result
  end

  # Find commits before a certain date. This is used when going forward through pages (1 -> 2) of commits.
  def find_commits_before(search_options, token, inclusive)
    repos = search_options[:repos].blank? ? @repos : repos_which_match(search_options[:repos])
    limit = search_options[:limit]
    extra_options = token ? { :before => token.timestamp } : {}
    results = commits_from_repos(repos, MetaRepo.git_command_options(search_options).merge(extra_options),
        limit, :first, search_options[:commit_filter_proc])

    token_index = token.nil? ? 0 : results.index do |commit|
      [:timestamp, :repo_name, :sha].all? { |p| commit.send(p) == token.send(p) }
    end

    if token_index
      token_index += 1 unless inclusive
      results = results[token_index, limit]
      results = [] unless results
    end

    results
  end

  # Find commits after a certain date. This is used when going backward through pages (2 -> 1) of commits.
  # - should_pad_results: true if we should always try to return a full page of commits when we hit the
  #   boundary of commits as defined by the paging token, even if some of those commits are *before* the token
  #   we've been given. This is an important capability for the paging UX, when you go from the second page
  #   back to the first page. If the first page has some new commits on it, we want to be sure to return a
  #   full page worth of data instead of just a single commit.
  def find_commits_after(search_options, token, inclusive, should_pad_results)
    repos = search_options[:repos].blank? ? @repos : repos_which_match(search_options[:repos])
    limit = search_options[:limit]
    extra_options = { :after => token.timestamp }
    results = commits_from_repos(repos, MetaRepo.git_command_options(search_options).merge(extra_options),
        search_options[:limit], :last, search_options[:commit_filter_proc])

    token_index = results.index do |commit|
      [:timestamp, :repo_name, :sha].all? { |p| commit.send(p) == token.send(p) }
    end
    token_index -= 1 if token && !inclusive
    if token_index >= 0
      results = results[[token_index - limit + 1, 0].max..token_index]
    else
      results = []
    end

    # We've gone as far back as possible; return the last N resuls. See note on should_pad_results.
    if results.size < limit && should_pad_results
      results += find_commits_before(search_options.merge(:limit => limit - results.size), token,
          !inclusive)
    end
    results
  end

  # Like GitHelper#rev_list, but it multiplexes across given repos and sorts the results.
  # retain: either :first or :last -- indicates which part of the result to truncate if there are more than
  # `limit` commits.
  # NOTE(caleb): If there are multiple commits matching the timestamp in :before or :after, then they will
  # *all* be returned, in addition to the `limit` commits before/after them. This is so that other methods in
  # this class can handle the corner case of many commits clustered around the paging token (i.e. at the same
  # timestamp).
  def commits_from_repos(repos, git_command_options, limit, retain = :first, commit_filter_proc = nil)
    raise "Can't change the sort order" if git_command_options[:reverse]
    git_command_options = git_command_options.clone

    # Need to explicitly handle the before/after corner cases.
    original_timestamp = git_command_options[:before] || git_command_options[:after]

    # Exclude the commits on the boundary; we'll add them in later.
    git_command_options[:before] -= 1 if git_command_options[:before]
    git_command_options[:after] += 1 if git_command_options[:after]

    commits = []
    repos.each do |repo|
      local_results = commits_from_repo(repo, git_command_options, limit, retain, commit_filter_proc)

      # If two commits have the same timestamp, we want to order them as they were originally ordered by
      # GitHelper.commits_with_limit. We could just sort by timestamp if Ruby's sort was stable, but it's not.
      # Instead, we must remember the array position of each commit so that we can use this later to sort.
      commits += local_results.each_with_index.map do |commit, i|
        [commit, [commit.timestamp, commit.repo_name, i]]
      end
    end

    # Hokay, now let's add in all the boundary commits (if necessary)
    boundary_commits = []
    if original_timestamp
      git_command_options[:before] = git_command_options[:after] = original_timestamp
      repos.each do |repo|
        # Hopefully there aren't > 1000 commits with a single timestamp...
        local_results = commits_from_repo(repo, git_command_options, 1000, retain, commit_filter_proc)
        boundary_commits += local_results.each_with_index.map do |commit, i|
          [commit, [commit.timestamp, commit.repo_name, i]]
        end
      end
    end

    commits.sort! { |commit1, commit2| compare_commit_tuples(commit1[1], commit2[1]) }
    boundary_commits.sort! { |commit1, commit2| compare_commit_tuples(commit1[1], commit2[1]) }
    results = (retain == :first) ?
        boundary_commits + commits.take(limit) :
        commits.last(limit) + boundary_commits
    results.map(&:first)
  end

  # Retrives commits from a single repo.
  # - commit_filter_proc: if provided, this filter is used to eliminate commits. This will page
  #   through all commits which satisfy the given search criteria until enough commits are found which are
  #   approved by the commit_filter_proc.
  def commits_from_repo(repo, git_command_options, limit, retain, commit_filter_proc = nil)
    git_command_options = git_command_options.dup
    filtered_results = []

    # Only go back 20 pages. This will prevent us from spinning through a full git history if we
    # ever encounter a dataset where commit_filter_proc continually returns false for each commit we find.
    max_git_pages_to_search = 20
    current_page_attempt = 0

    # If a filter_proc has been provided, we may need to make multiple invocations to git rev-list in case
    # the first list of commits we got from git rev-list were not all approved by the filter_proc.
    # We'll ask for more than we need if there's a filter_proc, so that we'll hopefully reduce how many
    # invocations we'll need to make to git rev-list.
    limit_with_padding = commit_filter_proc ? limit * 2 : limit
    begin
      original_results = GitHelper.commits_with_limit(repo, git_command_options, limit_with_padding + 1,
          :commits, retain)
      has_more = (original_results.size > limit_with_padding)
      # Commits are ordered by git ordering, so grab the first limit_with_padding amount when paging to
      # older commits and the last limit_with_padding amount when paging to newer commits.
      original_results = (retain == :first) ?
          original_results.take(limit_with_padding) :
          original_results.last(limit_with_padding)
      filtered_results += commit_filter_proc ?
          commit_filter_proc.call(original_results) :
          original_results

      if has_more
        if retain == :first
          oldest_commit = original_results.last
          git_command_options[:before] = oldest_commit.timestamp - 1
        elsif retain == :last
          newest_commit = original_results.first
          git_command_options[:after] = newest_commit.timestamp + 1
        end
      end
      current_page_attempt += 1
    end while (has_more && filtered_results.size < limit && current_page_attempt < max_git_pages_to_search)

    if retain == :last
      # We want the end of this list of commits in the case where we're paging to the left (backwards) through
      # commits.
      start = [filtered_results.size - limit, 0].max
      filtered_results[start, limit]
    else
      filtered_results.take(limit)
    end
  end

  # Number of commits preceding the token. Right now this is actually only a close estimate (it doesn't deal
  # with the conflicting timestamps case). AFAIK this is probably fine (for now) because this will only be
  # used for page numbering (which is going to be off when we import commits anyway).
  # NOTE(caleb) this should return >= the actual count.
  def count_commits_to_token(search_options, token)
    repos = search_options[:repos].blank? ? @repos : repos_which_match(search_options[:repos])
    git_command_options = MetaRepo.git_command_options(search_options).merge(:after => token.timestamp)

    count = 0
    # TODO(caleb): Fix the case where we've paged back > 10000 commits into a single repo.
    repos.each do |repo|
      count += GitHelper.commits_with_limit(repo, git_command_options, 10_000, :count, :first)
    end
    count
  end

  # Compare two commit tuples: [timestamp, repo_name, index]
  # (Index represents the git ordering). We want to order by decreasing timestamp, and break ties by
  # increasing (repo, index). This preserves the git order nicely across commits spanning multiple repos.
  def compare_commit_tuples(tuple1, tuple2)
    compare = tuple2[0] <=> tuple1[0]
    return compare unless compare.zero?
    [tuple1[1], tuple1[2]] <=> [tuple2[1], tuple2[2]]
  end

  # Returns the repos which have names matching any of the given regular expressions.
  def repos_which_match(repo_names)
    @repos.select { |repo| repo_names.include?(repo.name) }
  end

  # Converts the given search filter options to an arguments array and git CLI options, to be passed to git
  # rev-list.
  # The git_command_options has the form
  #    { :option1 => ..., :option2 => ..., :cli_args => ... }
  # where each option will be added as an --option to the rev_list command, followed by any CLI args
  # found in cli_args.
  def self.git_command_options(search_options)
    # TODO(caleb): Deal with filtering commit messages
    # Need extended regexes to be able to use the  "|" operator.
    # TODO(philc): Shouldn't we only add extended_regexp if authors is specified?
    git_options = { :extended_regexp => true, :regexp_ignore_case => true }

    git_options[:author] = search_options[:authors].join("|") unless search_options[:authors].blank?

    git_options[:after] = search_options[:after] unless search_options[:after].blank?

    git_arguments = search_options[:branches].blank? ? [] :
        search_options[:branches].map { |name| "origin/#{name}" }
    git_options[:all] = true if git_arguments.empty?
    git_arguments << "--"
    git_arguments += search_options[:paths] unless search_options[:paths].blank?

    git_options.merge(:cli_args => git_arguments)
  end

  private

  def repos_out_of_date?
    repo_names = Dir.glob("#{@repos_root}/*/").map { |path| File.basename(path) }
    Set.new(repo_names) != Set.new(@repos.map(&:name))
  end

  # Creates a new Grit::Repo object for the given path.
  def create_grit_repo_for_name(repo_name)
    path = Pathname.new(File.join(@repos_root, repo_name)).realpath.to_s
    grit_repo = Grit::Repo.new(path)
    grit_repo.name = repo_name
    grit_repo
  end
end

if __FILE__ == $0
  require "lib/script_environment"
  puts "Running commit importer as standalone script."
  GitDiffUtils.setup(RedisManager.redis_instance)
  MetaRepo.instance.import_new_commits!
end

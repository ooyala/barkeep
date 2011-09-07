# A module that encapsulates operations over a collection of git repositories.
# TODO(caleb): This file has a ton of logic I need to test.
# TODO(caleb): move the code around a bit so this is all a bit more logical and easy to follow. Most of this
# logic should live in files inside lib/commit_search/.

require "grit"
require "methodchain"

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/grit_extensions"
require "lib/commit_search/paging_token"
require "lib/git_helper"

class MetaRepo
  # This is the singleton instance that the app and all models use.
  class << self
    def logger=(logger); @@logger = logger; end
    def instance; @instance ||= MetaRepo.new; end
    def configure(logger, repo_paths)
      @@logger = logger
      @@repo_paths = repo_paths
    end
  end

  def initialize
    Thread.abort_on_exception = true
    @@logger.info "Initializing #{@@repo_paths.size} git repositories."
    # Let's keep this mapping in memory at all times -- we'll be hitting it all the time.
    @repo_name_to_id = {}
    @repos = []
    # A convenient lookup table for Grit::Repos keyed by both string name and db id.
    @repo_names_and_ids_to_repos = {}
    @@repo_paths.each do |path|
      # Canonical path
      path = Pathname.new(path).realpath.to_s
      name = File.basename(path)
      @@logger.info "Initializing repo '#{name}' at #{path}."
      raise "Error: Already have repo named #{name}" if @repo_name_to_id[name]
      id = GitRepo.find_or_create(:name => name, :path => path).id
      grit_repo = Grit::Repo.new(path)
      grit_repo.name = name
      @repos << grit_repo
      @repo_name_to_id[name] = id
      @repo_names_and_ids_to_repos[name] = grit_repo
      @repo_names_and_ids_to_repos[id] = grit_repo
    end
  end

  def db_commit(repo_name, sha)
    Commit[:git_repo_id => @repo_name_to_id[repo_name], :sha => sha]
  end

  # Returns nil if the given commit doesn't exist or is no longer on-disk
  # (because the repo was removed or mistakenly rebased).
  def grit_commit(repo_name_or_id, sha)
    # The grit_repo can be nil if the user has removed the repo from disk.
    grit_repo = @repo_names_and_ids_to_repos[repo_name_or_id]
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
    git_options, git_args = MetaRepo.git_options_and_args_from_search_filter_options(search_options)
    grit_repo = @repo_names_and_ids_to_repos[repo_id_or_name]
    grit_commit = grit_repo.commit(commit_sha)

    # git rev-list wants the commit ID to be the first argument.
    git_args.unshift(commit_sha)

    # Building up this rev-list command is a bit tricky. --all is added to the CL args if we're searching
    # across all branches. --all includes all refs as part of the command, so rev-list will simply return the
    # most recent commits from *any* ref which match the search criteria. What we want to do in that case is
    # limit the time range of the returned commits to match the commit we're looking for. We ask for 10
    # commits and see if the commit we're looking for is in that list, just in case there's more than one
    # commit with the same date (rare).
    git_options[:n] = 10
    git_options["min-age"] = git_options["max-age"] = grit_commit.date.to_i

    repos = search_options[:repos].blank? ? @repos :
        repos_which_match(search_options[:repos].map { |name| Regexp.new(name) })

    commit_matches_search = false
    # NOTE(philc): Doing this serially for now, as running git rev-list with popen from multiple threads
    # using "parallel_each_repos" was consistently giving a broken pipe error.
    commit_matches_search = repos.any? do |repo|
      commit_ids = GitHelper.rev_list(repo, git_options, git_args).map(&:sha)
      commit_ids.include?(grit_commit.sha)
    end
  end

  # Returns a page of commits based on the given options.
  # options:
  #  - authors: a list of authors
  #  - repos: a list of repo paths
  #  - branches: a list of branch names
  #
  # returns: { :commits => [git commits], :count => number of results,
  #            :tokens => { :from => new search token, :to => new search token } }
  def find_commits(options)
    git_options, git_args = MetaRepo.git_options_and_args_from_search_filter_options(options)
    repos = options[:repos].blank? ? @repos :
        repos_which_match(options[:repos].map { |name| Regexp.new(name) })

    # Assuming everything has been set up correctly in preparation to invoke git rev-list, add in options for
    # the limit and timestamp.
    token = options[:token].then { |token_string| PagingToken.from_s(token_string) }
    if options[:direction] == "before"
      commits = find_commits_before(repos, token, options[:limit], token.nil?, true, git_options,
                                         git_args)
    else
      commits = find_commits_after(repos, token, options[:limit], false, true, git_options, git_args)
    end
    return { :commits => [], :count => 0, :tokens => { :from => nil, :to => nil } } if commits.empty?

    result = { :commits => commits }
    tokens = {}
    [[:from, commits.last], [:to, commits.first]].each do |token_name, commit|
      tokens[token_name] = PagingToken.new(commit.timestamp, commit.repo_name, commit.sha)
    end
    result[:count] = count_commits_to_token(repos, tokens[:to], git_options, git_args)
    result[:tokens] = { :from => tokens[:from].to_s, :to => tokens[:to].to_s }
    result
  end

  def import_new_commits!
    # TODO(caleb): lots of logging and error checking here.
    @repo_name_to_id.each do |repo_name, repo_id|
      grit_repo = @repo_names_and_ids_to_repos[repo_id]
      grit_repo.git.fetch
      @@logger.info "Importing new commits for repo #{repo_name}."
      grit_repo.remotes.each do |remote|
        next if remote.name == "origin/HEAD"
        new_commits = import_new_ancestors!(repo_name, repo_id, remote.commit)
        @@logger.info "Imported #{new_commits} new commits as ancestors of #{remote.name} in repo #{repo_name}"
      end
    end
  end

  private

  # Import all undiscovered ancestors. Returns the number of new commits imported.
  # This method can import a new repository of 25K commits in about 40s.
  def import_new_ancestors!(repo_name, repo_id, grit_commit)
    # A value of 200 is not so useful when we're importing single new commits, but really useful when we're
    # importing a brand new repository. Setting this page size to 2,000 will result in a stack overflow --
    # Grit must fetch commits recursively.
    page_size = 200
    page = 0
    total_added = 0

    begin
      # repo.commits is ultimately shelling out to git rev-list.
      commits = grit_commit.repo.commits(grit_commit.sha, page_size, page * page_size)

      existing_commits = Commit.filter(:sha => commits.map(&:sha), :git_repo_id => repo_id).select(:sha).all
      break if existing_commits.size >= page_size

      existing_shas = Set.new(existing_commits.map { |commit| commit.sha })

      rows_to_insert = commits.map do |commit|
        next if existing_shas.include?(commit.sha)

        user = User.find_or_create(:email => commit.author.email) do |new_user|
          new_user.name = commit.author.name
        end

        GitHelper::get_tagged_commit_diffs(repo_name, commit, :cache_prime => true)

        {
          :git_repo_id => repo_id,
          :sha => commit.sha,
          :message => commit.message,
          # NOTE(caleb): For some reason, the commit object you get from a remote returns nil for #date (but
          # it does have #authored_date and #committed_date. Bug?
          :date => commit.authored_date,
          :user_id => user.id
        }
      end
      rows_to_insert.reject!(&:nil?)

      # We're doing a single multi-insert statement because it's roughly 2x faster than doing insert
      # statements one by one.
      Commit.multi_insert(rows_to_insert)

      total_added += rows_to_insert.size
      page += 1

      # Give some progress output for really big imports.
      @@logger.info "Imported #{page_size * page} commits..." if (page % 10 == 0)
    rescue Sequel::DatabaseDisconnectError => e
      # NOTE(dmac): This will occur the first time the background job runs, because it's
      # trying to reconnect to the database. If we retry, the connection will be
      # reestablished and ingestion will continue on its merry way.
      redo
    rescue Exception => e
      @@logger.info "Exception raised while importing commits:"
      @@logger.info "#{e.class}"
      @@logger.info "#{e.message}"
      @@logger.info "#{e.backtrace}"
      raise e
    end until commits.empty?

    total_added
  end

  # TODO(caleb): the following two methods are too copy-pasta, but at the same time they're quite complex so
  # when we combine them we should make sure that it is understandable what's happening.

  def find_commits_before(repos, token, limit, inclusive, pad_results, options, args)
    extra_options = token ? { :before => token.timestamp } : {}
    results = commits_from_repos(repos, options.merge(extra_options), args, limit, :first)

    token_index = token.nil? ? 0 : results.index do |commit|
      [:timestamp, :repo_name, :sha].all? { |p| commit.send(p) == token.send(p) }
    end
    if token_index
      token_index += 1 unless inclusive
      results = results[token_index, limit]
      results = [] unless results
    end

    # We've gone as far back as possible; return the last N resuls.
    if results.size < limit && pad_results && token
      results = find_commits_after(repos, token, limit - results.size, !inclusive, false, options,
                                        args) + results
    end
    results
  end

  def find_commits_after(repos, token, limit, inclusive, pad_results, options, args)
    extra_options = { :after => token.timestamp }
    results = commits_from_repos(repos, options.merge(extra_options), args, limit, :last)

    token_index = results.index do |commit|
      [:timestamp, :repo_name, :sha].all? { |p| commit.send(p) == token.send(p) }
    end
    token_index -= 1 if token && !inclusive
    if token_index >= 0
      results = results[[token_index - limit + 1, 0].max..token_index]
    else
      results = []
    end

    # We've gone as far back as possible; return the last N resuls.
    if results.size < limit && pad_results
      results +=
        find_commits_before(repos, token, limit - results.size, !inclusive, false, options, args)
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
  def commits_from_repos(repos, options, args, limit, retain = :first)
    raise "Can't change the sort order" if options[:reverse]
    git_options = options.clone

    # Need to explicitly handle the before/after corner cases.
    original_timestamp = git_options[:before] || git_options[:after]
    # Exclude the commits on the boundary; we'll add them in later.
    git_options[:before] -= 1 if git_options[:before]
    git_options[:after] += 1 if git_options[:after]

    commits = []
    parallel_each_repos(repos) do |repo, mutex|
      local_results = GitHelper.commits_with_limit(repo, git_options, args, limit, :commits, retain)
      # This BS is because ruby's sort isn't stable, but I need to preserve the git ordering of commits beyond
      # timestamp.
      commit_tuples = local_results.each_with_index.map do |commit, i|
        [commit, [commit.timestamp, commit.repo_name, i]]
      end
      mutex.synchronize { commits += commit_tuples }
    end

    # Hokay, now let's add in all the boundary commits (if necessary)
    boundary_commits = []
    if original_timestamp
      git_options[:before] = git_options[:after] = original_timestamp
      parallel_each_repos(repos) do |repo, mutex|
        # Hopefully there aren't > 1000 commits with a single timestamp...
        local_results = GitHelper.commits_with_limit(repo, git_options, args, 1000, :commits, retain)
        commit_tuples = local_results.each_with_index.map do |commit, i|
          [commit, [commit.timestamp, commit.repo_name, i]]
        end
        mutex.synchronize { boundary_commits += commit_tuples }
      end
    end

    commits.sort! { |commit1, commit2| compare_commit_tuples(commit1[1], commit2[1]) }
    boundary_commits.sort! { |commit1, commit2| compare_commit_tuples(commit1[1], commit2[1]) }
    results = retain == :first ? boundary_commits + commits.take(limit) :
      commits.last(limit) + boundary_commits
    results.map(&:first)
  end

  # Number of commits preceding the token. Right now this is actually only a close estimate (it doesn't deal
  # with the conflicting timestamps case). AFAIK this is probably fine (for now) because this will only be
  # used for page numbering (which is going to be off when we import commits anyway).
  # NOTE(caleb) this should return >= the actual count.
  def count_commits_to_token(repos, token, options, args)
    count = 0
    # TODO(caleb): Fix the case where we've paged back > 10000 commits into a single repo.
    parallel_each_repos(repos) do |repo, mutex|
      local_count = GitHelper.commits_with_limit(repo, options.merge({:after => token.timestamp}), args,
                                                 10_000, :count, :first)
      mutex.synchronize { count += local_count }
    end
    count
  end

  # Perform some operation with a thread for each repo.
  # Caller gets a thread-local repo and a mutex.
  def parallel_each_repos(repos, &block)
    mutex = Mutex.new
    threads = repos.map do |r|
      Thread.new(r) do |repo|
        yield repo, mutex
      end
    end
    threads.each(&:join)
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
  def repos_which_match(regexps)
    repos = []
    @repo_name_to_id.each do |name, id|
      repos << @repo_names_and_ids_to_repos[id] if regexps.any? { |regexp| name =~ regexp }
    end
    repos.uniq
  end

  # Converts the given search filter options to an arguments array and git CLI options, to be passed to git
  # rev-list.
  def self.git_options_and_args_from_search_filter_options(options)
    # TODO(caleb): Deal with filtering commit messages
    # Need extended regexes to be able to use the  "|" operator.
    git_options = { :extended_regexp => true, :regexp_ignore_case => true }

    git_options[:author] = options[:authors].join("|") unless options[:authors].blank?

    git_arguments = options[:branches].blank? ? [] : options[:branches].map { |name| "origin/#{name}" }
    git_options[:all] = true if git_arguments.empty?
    git_arguments << "--"
    git_arguments += options[:paths] unless options[:paths].blank?

    return git_options, git_arguments
  end
end

if __FILE__ == $0
  require "lib/script_environment"
  puts "Running commit importer as standalone script."
  GitHelper.initialize_git_helper(RedisManager.get_redis_instance)
  MetaRepo.instance.import_new_commits!
end

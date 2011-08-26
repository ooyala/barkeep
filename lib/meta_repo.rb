# A module that encapsulates operations over a collection of git repositories.
# TODO(caleb): This file has a ton of logic I need to test.
# TODO(caleb): move the code around a bit so this is all a bit more logical and easy to follow. Most of this
# logic should live in files inside lib/commit_search/.

require "grit"
require "methodchain"

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/grit_extensions"
require "lib/script_environment"
require "lib/commit_search/paging_token"

# TODO(philc): Make this an instantiable class so we don't need to pass around a logger in every method.
module MetaRepo
  def self.initialize_meta_repo(logger, repo_paths)
    Thread.abort_on_exception = true
    logger.info "Initializing #{repo_paths.size} git repositories."
    # Let's keep this mapping in memory at all times -- we'll be hitting it all the time.
    @@repo_name_to_id = {}
    @@repos = []
    # A convenient lookup table for Grit::Repos keyed by both string name and db id.
    @@repo_names_and_ids_to_repos = {}
    repo_paths.each do |path|
      # Canonical path
      path = Pathname.new(path).realpath.to_s
      name = File.basename(path)
      logger.info "Initializing repo '#{name}' at #{path}."
      raise "Error: Already have repo named #{name}" if @@repo_name_to_id[name]
      id = GitRepo.find_or_create(:name => name, :path => path).id
      grit_repo = Grit::Repo.new(path)
      grit_repo.name = name
      @@repos << grit_repo
      @@repo_name_to_id[name] = id
      @@repo_names_and_ids_to_repos[name] = grit_repo
      @@repo_names_and_ids_to_repos[id] = grit_repo
    end
  end

  def self.db_commit(repo_name, sha)
    Commit[:git_repo_id => @@repo_name_to_id[repo_name], :sha => sha]
  end

  def self.grit_commit(repo_name_or_id, sha)
    grit_repo = @@repo_names_and_ids_to_repos[repo_name_or_id]
    grit_commit = grit_repo.commit(sha)
    grit_commit.repo_name = File.basename(grit_repo.working_dir)
    grit_commit
  end

  # returns: { :commits => [git commits], :count => number of results,
  #            :tokens => { :from => new search token, :to => new search token } }
  def self.find_commits(options)
    # TODO(caleb): Deal with these filters:
    #   * branches
    #   * paths
    #   * messages

    # Need extended regexes to get |.
    git_options = { :extended_regexp => true, :regexp_ignore_case => true }
    # Assuming authors is a comma-separated list.
    if options[:authors] && !options[:authors].empty?
      git_options[:author] = options[:authors].split(",").map(&:strip).join("|")
    end
    git_args = options[:branches].then { split(",").map(&:strip).map { |name| "origin/#{name}" } }.else { [] }
    repos = @@repos

    # now, assuming options has everything set up correctly for rev-list except for limit and timestamp stuff

    token = options[:token].then { |token_string| PagingToken.from_s(token_string) }
    if options[:direction] == "before"
      commits = self.find_commits_before(repos, token, options[:limit], token.nil?, true, git_options,
                                         git_args)
    else
      commits = self.find_commits_after(repos, token, options[:limit], false, true, git_options, git_args)
    end
    return { :commits => [], :count => 0, :tokens => { :from => nil, :to => nil } } if commits.empty?

    result = { :commits => commits }
    tokens = {}
    [[:from, commits.last], [:to, commits.first]].each do |token_name, commit|
      tokens[token_name] = PagingToken.new(commit.timestamp, commit.repo_name, commit.sha)
    end
    result[:count] = self.count_commits_to_token(repos, tokens[:to], git_options, git_args)
    result[:tokens] = { :from => tokens[:from].to_s, :to => tokens[:to].to_s }
    result
  end

  def self.import_new_commits!(logger)
    # TODO(caleb): lots of logging and error checking here.
    @@repo_name_to_id.each do |repo_name, repo_id|
      grit_repo = @@repo_names_and_ids_to_repos[repo_id]
      grit_repo.git.fetch
      logger.info "Importing new commits for repo #{repo_name}."
      grit_repo.remotes.each do |remote|
        next if remote.name == "origin/HEAD"
        new_commits = self.import_new_ancestors!(logger, repo_id, remote.commit)
        logger.info "Imported #{new_commits} new commits as ancestors of #{remote.name} in repo #{repo_name}"
      end
    end
  end

  # private

  # Import all undiscovered ancestors. Returns the number of new commits imported.
  # This method can import a new repository of 25K commits in about 40s.
  def self.import_new_ancestors!(logger, repo_id, grit_commit)
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
      logger.info "Imported #{page_size * page} commits..." if (page % 10 == 0)

    end until commits.empty?

    total_added
  end

  # TODO(caleb): the following two methods are too copy-pasta, but at the same time they're quite complex so
  # when we combine them we should make sure that it is understandable what's happening.

  def self.find_commits_before(repos, token, limit, inclusive, pad_results, options, args)
    extra_options = token ? { :before => token.timestamp } : {}
    results = self.commits_from_repos(repos, options.merge(extra_options), args, limit, :first)

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
      results = self.find_commits_after(repos, token, limit - results.size, !inclusive, false, options,
                                        args) + results
    end
    results
  end

  def self.find_commits_after(repos, token, limit, inclusive, pad_results, options, args)
    extra_options = { :after => token.timestamp }
    results = self.commits_from_repos(repos, options.merge(extra_options), args, limit, :last)

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
        self.find_commits_before(repos, token, limit - results.size, !inclusive, false, options, args)
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
  def self.commits_from_repos(repos, options, args, limit, retain = :first)
    raise "Can't change the sort order" if options[:reverse]
    git_options = options.clone

    # Need to explicitly handle the before/after corner cases.
    original_timestamp = git_options[:before] || git_options[:after]
    # Exclude the commits on the boundary; we'll add them in later.
    git_options[:before] -= 1 if git_options[:before]
    git_options[:after] += 1 if git_options[:after]

    commits = []
    self.parallel_each_repos(repos) do |repo, mutex|
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
      self.parallel_each_repos(repos) do |repo, mutex|
        # Hopefully there aren't > 1000 commits with a single timestamp...
        local_results = GitHelper.commits_with_limit(repo, git_options, args, 1000, :commits, retain)
        commit_tuples = local_results.each_with_index.map do |commit, i|
          [commit, [commit.timestamp, commit.repo_name, i]]
        end
        mutex.synchronize { boundary_commits += commit_tuples }
      end
    end

    commits.sort! { |commit1, commit2| self.compare_commit_tuples(commit1[1], commit2[1]) }
    boundary_commits.sort! { |commit1, commit2| self.compare_commit_tuples(commit1[1], commit2[1]) }
    results = retain == :first ? boundary_commits + commits.take(limit) :
      commits.last(limit) + boundary_commits
    results.map(&:first)
  end

  # Number of commits preceding the token. Right now this is actually only a close estimate (it doesn't deal
  # with the conflicting timestamps case). AFAIK this is probably fine (for now) because this will only be
  # used for page numbering (which is going to be off when we import commits anyway).
  # NOTE(caleb) this should return >= the actual count.
  def self.count_commits_to_token(repos, token, options, args)
    count = 0
    # TODO(caleb): Fix the case where we've paged back > 10000 commits into a single repo.
    self.parallel_each_repos(repos) do |repo, mutex|
      local_count = GitHelper.commits_with_limit(repo, options.merge({:after => token.timestamp}), args,
                                                 10_000, :count, :first)
      mutex.synchronize { count += local_count }
    end
    count
  end

  # Perform some operation with a thread for each repo.
  # Caller gets a thread-local repo and a mutex.
  def self.parallel_each_repos(repos, &block)
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
  def self.compare_commit_tuples(tuple1, tuple2)
    compare = tuple2[0] <=> tuple1[0]
    return compare unless compare.zero?
    [tuple1[1], tuple1[2]] <=> [tuple2[1], tuple2[2]]
  end
end

if __FILE__ == $0
  puts "Running commit importer as standalone script."
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG
  MetaRepo.initialize_meta_repo(logger, REPO_PATHS)
  MetaRepo.import_new_commits!(logger)
end

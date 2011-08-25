# A module that encapsulates operations over a collection of git repositories.

require "grit"

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/grit_extensions"
require "lib/script_environment"

# TODO(philc): Make this an instantiable class so we don't need to pass around a logger in every method.
module MetaRepo
  def self.initialize_meta_repo(logger, repo_paths)
    logger.info "Initializing #{repo_paths.size} git repositories."
    # Let's keep this mapping in memory at all times -- we'll be hitting it all the time.
    @@repo_name_to_id = {}
    # A convenient lookup table for Grit::Repos keyed by both string name and db id.
    @@repo_names_and_ids_to_repos = {}
    repo_paths.each do |path|
      name = File.basename(path)
      logger.info "Initializing repo '#{name}' at #{path}."
      raise "Error: Already have repo named #{name}" if @@repo_name_to_id[name]
      id = GitRepo.find_or_create(:name => name, :path => path).id
      grit_repo = Grit::Repo.new(path)
      @@repo_name_to_id[name] = id
      @@repo_names_and_ids_to_repos[name] = grit_repo
      @@repo_names_and_ids_to_repos[id] = grit_repo
    end
  end

  def self.db_commit(repo_name, sha)
    Commit[:git_repo_id => @@repo_name_to_id[repo_name], :sha => sha]
  end

  def self.grit_commit(repo_name_or_id, sha)
    @@repo_names_and_ids_to_repos[repo_name_or_id].commit(sha)
  end

  # Takes care of multiplexing across multiple repositories and then uses GItHelper#find_commits to locate the
  # actual commits per repo.
  def self.find_commits(options, count, timestamp = Time.now, previous = true)
    # TODO(caleb)
    repo = @@repo_name_to_id.keys.first
    commits = GitHelper.find_commits(@@repo_names_and_ids_to_repos[repo], options, count, timestamp, previous)
    commits.each { |commit| commit.repo_name = repo }
    commits
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
      print "#{page_size * page}..." if (page % 10 == 0)

    end until commits.empty?
    print "\n"

    total_added
  end
end

if __FILE__ == $0
  puts "Running commit importer as standalone script."
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG
  MetaRepo.initialize_meta_repo(logger, REPO_PATHS)
  MetaRepo.import_new_commits!(logger)
end
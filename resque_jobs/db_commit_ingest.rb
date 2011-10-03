# A Resque job which takes a repo name and a git remote ("master" or some other branch) and pages through
# commits, inserting DB records for those commits which are not yet in the DB.
# This Resque job is designed to be queued up right after we've run "git fetch" on a repo and we've detected
# that there is some number of new commits that we should import.
$LOAD_PATH.push("../") unless $LOAD_PATH.include?("../")
require "lib/script_environment"
require "resque"
require "set"

class DbCommitIngest
  @queue = :db_commit_ingest

  # Called by Resque.
  def self.perform(repo_name, remote_name)
    logger = Logging.logger = Logging.create_logger("db_commit_ingest.log")
    logger.info "Importing new commits from #{repo_name}:#{remote_name} into the database."
    MetaRepo.logger = logger

    # Reconnect to the database if our connection has timed out.
    Comment.select(1).first rescue nil

    # A value of 200 is not so useful when we're importing single new commits, but really useful when we're
    # importing a brand new repository. Setting this page size to 2,000 will result in a stack overflow --
    # Grit must fetch commits recursively.
    page_size = 200
    page = 0

    begin
      repo = MetaRepo.instance.grit_repo_for_name(repo_name)
      db_repo = GitRepo.first(:name => repo_name)
      # repo.commits is ultimately shelling out to git rev-list.
      commits = repo.commits(remote_name, page_size, page * page_size)

      existing_commits =
          Commit.filter(:sha => commits.map(&:sha), :git_repo_id => db_repo.id).select(:sha).all
      break if existing_commits.size >= page_size

      existing_shas = Set.new(existing_commits.map { |commit| commit.sha })

      rows_to_insert = commits.map do |commit|
        next if existing_shas.include?(commit.sha)

        user = User.find_or_create(:email => commit.author.email) do |new_user|
          new_user.name = commit.author.name
        end

        # TODO(philc): Queue up a job to cache tagged diffs for this file.
        Resque.enqueue(GenerateTaggedDiffs, repo_name, commit.sha)

        {
          :git_repo_id => db_repo.id,
          :sha => commit.sha,
          :message => commit.message,
          # NOTE(caleb): For some reason, the commit object you get from a remote returns nil for #date (but
          # it does have #authored_date and #committed_date. Bug?
          :date => commit.authored_date,
          :user_id => user.id
        }
      end
      rows_to_insert.reject!(&:nil?)

      # A single multi-insert statement is ~2x faster than doing insert statements one at a time.
      Commit.multi_insert(rows_to_insert)

      page += 1

      # Give some progress output for really big imports.
      logger.info "Imported #{page_size * page} commits..." if (page % 10 == 0)
    rescue Exception => error
      logger.info "Exception raised while inserting new commits into the DB:"
      logger.info "#{error.class}"
      logger.info "#{error.message}"
      logger.info "#{error.backtrace}"
      raise error
    end until commits.empty?
  end
end
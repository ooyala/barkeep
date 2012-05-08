# A Resque job which takes a repo name and a git remote ("master" or some other branch) and pages through
# commits, inserting DB records for those commits which are not yet in the DB.
# This Resque job is designed to be queued up right after we've run "git fetch" on a repo and we've detected
# that there is some number of new commits that we should import.
require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "resque"
require "set"
require "lib/resque_job_helper"

class DbCommitIngest
  include ResqueJobHelper
  @queue = :db_commit_ingest

  # Called by Resque.
  def self.perform(repo_name, remote_name)
    setup
    MetaRepo.instance.scan_for_new_repos

    # A value of 200 is not so useful when we're importing single new commits, but really useful when we're
    # importing a brand new repository. Setting this page size to 2,000 will result in a stack overflow --
    # Grit must fetch commits recursively.
    page_size = 200
    page = 0

    rows_to_insert = []
    repo = MetaRepo.instance.get_grit_repo(repo_name)
    db_repo = GitRepo.first(:name => repo_name)

    # We don't send new commit emails when ingesting a new repository.
    # A "new repository" is one which has 0 commits in the database.
    should_send_emails = Commit.filter(:git_repo_id => db_repo.id).select(1).count > 0

    begin
      # repo.commits is ultimately shelling out to git rev-list.
      commits = repo.commits(remote_name, page_size, page * page_size)

      existing_commits =
          Commit.filter(:sha => commits.map(&:sha), :git_repo_id => db_repo.id).select(:sha).all
      break if existing_commits.size >= page_size

      existing_shas = Set.new existing_commits.map(&:sha)

      page_of_rows_to_insert = commits.map do |commit|
        next if existing_shas.include?(commit.sha)

        {
          :git_repo_id => db_repo.id,
          :sha => commit.sha,
          :message => commit.message,
          # NOTE(caleb): For some reason, the commit object you get from a remote returns nil for #date (but
          # it does have #authored_date and #committed_date. Bug?
          :date => commit.authored_date,
        }
      end
      page_of_rows_to_insert.compact!

      # A single multi-insert statement is ~2x faster than doing insert statements one at a time.
      Commit.multi_insert(page_of_rows_to_insert)

      rows_to_insert += page_of_rows_to_insert
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

    # Enqueue commits in the logical ordering (particularly for sending emails).
    rows_to_insert.reverse.each do |row|
      Resque.enqueue(DeliverCommitEmails, repo_name, row[:sha]) if should_send_emails
      Resque.enqueue(GenerateTaggedDiffs, repo_name, row[:sha])
    end
  end
end

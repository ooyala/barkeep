require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"
require "grit"

# This migration populates the "author_id" field in the "commits" table.

Sequel.migration do
  up do
    # Fetch all the authors (expected to be small, say less than 1000) so that we don't have to do
    # an extra SQL query for every commit to check if the author email exists. Then create a mapping
    # from email -> author.id
    rows = DB[:authors].all
    authors = {}
    rows.each do |row|
      authors[row[:email]] = row[:id]
    end

    # Fetch all the git repos (also small, less than 100) and create a mapping from
    # git_repo_id -> Grit::Repo
    repos = {}
    DB[:git_repos].each { |row| repos[row[:id]] = Grit::Repo.new(row[:path]) }

    total_updates = 0
    new_authors = 0
    commits = DB[:commits].filter(:author_id => nil).all
    commits.each do |row|
      commit = repos[row[:git_repo_id]].commit(row[:sha])
      next unless commit
      email = commit.author.email
      author_id = authors[email]
      # If the author is not in our db, then add it.
      if author_id.nil?
        # Check if the same email exists in the users table.
        user = DB[:users].first(:email => email)
        user_id = user[:id] if user
        DB[:authors].insert(:email => email, :name => commit.author.name, :user_id => user_id)

        # Get the author_id and add it to the hash.
        author = DB[:authors].first(:email => email)
        author_id = author[:id]
        authors[email] = author_id
        new_authors += 1
      end
      total_updates += 1
      DB[:commits].filter(:id => row[:id]).update(:author_id => authors[email])
    end
    puts "New authors: #{new_authors}"
    puts "Updated commits: #{total_updates}"
  end

  # We don't need to undo this.
  down do
  end
end

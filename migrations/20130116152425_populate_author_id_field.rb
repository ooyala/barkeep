require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"
require "grit"

# This migration populates the "author_id" field in the "commits" table.

# This is the number of commits that we fetch at a time.
PAGE_SIZE = 100

Sequel.migration do
  up do
    repos = DB[:git_repos].all

    # Fetch all the authors (expected to be small, say less than 1000) so that we don't have to do
    # an extra SQL query for every commit to check if the author email exists. Then create a mapping
    # from email -> author.id
    rows = DB[:authors].all
    puts "Read #{rows.length} rows from the 'authors' table."
    authors = {}
    rows.each do |row|
      authors[row[:email]] = row[:id]
    end

    # Create a mapping from commit sha -> author email
    shas = Hash.new { |hash, key| hash[key] = {} }
    repos.each do |repo|
      grit_repo = Grit::Repo.new(repo[:path])
      total = 0
      num = 0
      begin
        commits = grit_repo.commits("master", PAGE_SIZE, total)
        commits.each do |commit|
          email = commit.author.email
          author_id = authors[email]
          if author_id.nil?
            # This shouldn't happen. We should already have the author in our db. But if not,
            # add the author to the db.
            user = DB[:users].first(:email => email)
            user_id = user[:id] if user
            DB[:authors].insert(:email => email, :name => commit.author.name, :user_id => user_id)

            # Get the author_id and add it to the hash.
            author = DB[:authors].first(:email => email)
            author_id = author[:id]
            authors[email] = author_id
          end

          # Update the author_id field.
          DB[:commits].filter(:sha => commit.sha).update(:author_id => author_id)
        end
        num = commits.length
        total += num
      end while num == PAGE_SIZE
      puts "Processed #{total} commits from repo #{repo[:path]}."
    end
  end

  # We don't need to undo this.
  down do
  end
end

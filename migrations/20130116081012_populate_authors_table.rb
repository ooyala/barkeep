require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"
require "grit"

# This migration populates the "authors" table by fetching all the commits from all the repos
# and storing the unique commit authors in the "authors" table. If it finds an identical email
# address in the "users" table then it also adds the "user_id" to the authors table entry.

# This is the number of commits that we fetch at a time.
PAGE_SIZE = 100

Sequel.migration do
  up do
    repos = DB[:git_repos].all

    # Find all the unique authors
    authors = Hash.new { |hash, key| hash[key] = {} }
    repos.each do |repo|
      grit_repo = Grit::Repo.new(repo[:path])
      total = 0
      num = 0
      begin
        commits = grit_repo.commits("master", PAGE_SIZE, total)
        commits.each { |commit| authors[commit.author.email][:name] = commit.author.name }
        num = commits.length
        total += num
      end while num == PAGE_SIZE
      puts "Processed #{total} commits from repo #{repo[:path]}."
    end

    # Find matching users (by email) in the "users" table.
    authors.keys.each do |email|
      user = DB[:users].first(:email => email)
      authors[email][:user_id] = user[:id] if user
    end
    puts "Found #{authors.length} unique authors."

    # Fill in the "authors" table.
    num_inserts = 0
    authors.each do |key, value|
      row = DB[:authors].first(:email => key)
      next if row
      DB[:authors].insert(:email => key, :name => value[:name], :user_id => value[:user_id])
      num_inserts += 1
    end
    puts "Inserted #{num_inserts} new authors."
  end

  # We don't need to remove the author entries.
  down do
  end
end

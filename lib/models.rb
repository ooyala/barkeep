require "rubygems"
require "sequel"

DB = Sequel.connect(:host => DB_HOST, :database => DB_NAME, :port => DB_PORT, :user => DB_USER,
                    :password => DB_PASSWORD, :adapter => "mysql2")

# This plugin gives you the "add_association_dependency" method, which lets you specify other objects to be
# destroyed when the current model gets destroyed, e.g. when you delete a provider, also delete its movies.
Sequel::Model.plugin :association_dependencies

# Auto-populate "created_at" and "updated_at" fields.
Sequel::Model.plugin :timestamps

require "models/git_repo"
require "models/git_branch"
require "models/author"
require "models/user"
require "models/saved_search"
require "models/commit"
require "models/commit_file"
require "models/comment"
require "models/completed_email"

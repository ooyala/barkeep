require "rubygems"
require "sequel"

DB = Sequel.sqlite("dev.db")

# This plugin gives you the "add_association_dependency" method, which lets you specify other objects to be
# destroyed when the current model gets destroyed, e.g. when you delete a provider, also delete its movies.
Sequel::Model.plugin :association_dependencies

# Auto-populate "created_at" and "updated_at" fields.
Sequel::Model.plugin :timestamps

require "models/user"
require "models/saved_search"
require "models/search_filter"
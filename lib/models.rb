require "rubygems"
require "sequel"

DB = Sequel.sqlite("dev.db")

require "models/saved_search"
require "models/search_filter"
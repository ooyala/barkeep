require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  change do
    add_column :comments, :closed_at, DateTime
  end
end

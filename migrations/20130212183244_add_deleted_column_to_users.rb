require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  change do
    alter_table(:users) { add_column :deleted_at, DateTime }
  end
end

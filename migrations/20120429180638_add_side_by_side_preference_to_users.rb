require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  change do
    alter_table(:users) do
      add_column :default_to_side_by_side, TrueClass, :default => false
    end
  end
end

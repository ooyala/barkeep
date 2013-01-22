require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  up do
    alter_table(:comments) do
      rename_column :completed_at, :resolved_at
    end
  end

  down do
    alter_table(:comments) do
      rename_column :resolved_at, :completed_at
    end
  end
end

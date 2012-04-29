require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  change do
    alter_table(:users) do
      add_column :line_length, :integer, :default => nil
    end
  end
end

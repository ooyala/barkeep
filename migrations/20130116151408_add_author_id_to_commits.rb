require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  change do
    alter_table :commits do
      add_foreign_key :author_id, :authors, :key => :id
    end
  end
end

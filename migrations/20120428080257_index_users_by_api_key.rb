require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  up do
    alter_table(:users) do
      add_index :api_key, :unique => true, :name => "api_key_is_unique_per_user"
    end
  end

  down do
    alter_table(:users) do
      drop_index :api_key, :name => "api_key_is_unique_per_user"
    end
  end
end

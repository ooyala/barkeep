require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"
require "lib/api"

Sequel.migration do
  up do
    alter_table(:users) do
      add_column :api_key, String, :default => "", :null => false
      add_column :api_secret, String, :default => "", :null => false
    end
    # Assign a key and secret to all existing users.
    DB[:users].all do |user|
      DB[:users][:id => user[:id]] = {
        :api_key => Api.generate_user_key,
        :api_secret => Api.generate_user_key
      }
    end
  end
  down do
    alter_table(:users) do
      drop_column :api_key
      drop_column :api_secret
    end
  end
end

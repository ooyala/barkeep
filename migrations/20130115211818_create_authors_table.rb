require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  change do
    create_table(:authors) do
      primary_key :id
      foreign_key :user_id, :users, :key => :id
      String :name
      String :email
    end
  end
end

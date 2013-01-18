require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  change do
    create_table(:review_requests) do
      primary_key :id
      foreign_key :requester_user_id, :users, :key => :id
      foreign_key :reviewer_user_id, :users, :key => :id
      foreign_key :commit_id, :commits, :key => :id
      DateTime :completed_at
      DateTime :requested_at
    end
  end
end

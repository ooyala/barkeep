require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  up do
    alter_table(:review_requests) do
      add_index [:reviewer_user_id, :completed_at]
      add_index [:requester_user_id, :completed_at]
    end
  end

  down do
    alter_table(:review_requests) do
      drop_index [:reviewer_user_id, :completed_at]
      drop_index [:requester_user_id, :completed_at]
    end
  end
end

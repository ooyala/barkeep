require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  up do
    alter_table(:comments) do
      add_index [:action_required, :closed_at]
    end
  end

  down do
    alter_table(:comments) do
      drop_index [:action_required, :closed_at]
    end
  end
end

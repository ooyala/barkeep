require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    alter_table(:commits) do
      drop_column :approved
      add_foreign_key :approved_by_user_id, :users
    end
  end

  down do
    alter_table(:commits) do
      drop_column :approved_by_user_id
      add_column :approved, FalseClass, :default => false
    end
  end
end

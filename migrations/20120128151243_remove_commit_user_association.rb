require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    alter_table(:commits) do
      drop_column :user_id
    end
  end

  down do
    alter_table(:commits) do
      add_foreign_key :user_id, :users
    end
  end
end

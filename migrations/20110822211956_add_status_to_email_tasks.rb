require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    alter_table :email_tasks do
      add_column :status, String
      add_index :status
    end
  end

  down do
    alter_table :email_tasks do
      drop_index :status
      drop_column :status
    end
  end
end

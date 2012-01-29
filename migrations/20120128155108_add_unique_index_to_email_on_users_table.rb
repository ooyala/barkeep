require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    alter_table(:users) do
      add_index :email, :unique => true, :name => "email_is_unique_per_user"
    end
  end

  down do
    alter_table(:users) do
      drop_index :email, :name => "email_is_unique_per_user"
    end
  end
end

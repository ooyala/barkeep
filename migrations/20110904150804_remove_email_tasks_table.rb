require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    drop_table :email_tasks
  end

  down do
    # Don't go back.
  end
end

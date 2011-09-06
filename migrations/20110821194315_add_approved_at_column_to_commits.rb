require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    add_column :commits, :approved_at, DateTime
  end

  down do
    remove_column :commits, :approved_at, DateTime
  end
end

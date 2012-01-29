require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  change do
    alter_table(:users) do
      add_column :permission, String, :default => "normal", :null => false
    end
  end
end

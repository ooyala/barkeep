require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  change do
    alter_table :saved_searches do
      add_column :branches, String
    end
  end
end

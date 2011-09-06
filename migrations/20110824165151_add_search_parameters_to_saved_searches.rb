require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  change do
    alter_table :saved_searches do
      add_column :repos, String
      add_column :authors, String
      add_column :paths, String
      add_column :messages, String
    end
  end
end

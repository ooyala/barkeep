require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  change do
    alter_table :commit_files do
      add_column :filename, String
      add_index [:filename]
    end
  end
end

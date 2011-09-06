require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  change do
    rename_table :files, :commit_files
    alter_table :comments do
      rename_column :file_id, :commit_file_id
    end

  end
end

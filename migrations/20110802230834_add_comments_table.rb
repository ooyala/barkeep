require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    create_table(:comments) do
      primary_key :id
      foreign_key :user_id, :users, :key => :id
      foreign_key :commit_file_id, :commit_files, :key => :id
      foreign_key :commit_id, :commits, :key => :id
      text :text
      int :line_number
      String :file_version
      datetime :created_at
      datetime :updated_at
    end
  end

  down do
    drop_table(:comments)
  end
end

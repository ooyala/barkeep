require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    create_table(:comments) do
      primary_key :id
      foreign_key :user_id, :users
      foreign_key :file_id, :files
      foreign_key :commit_id, :commits
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

require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  change do
    create_table :git_repos do
      primary_key :id
      String :name, :null => false, :unique => true
      String :path, :null => false, :unique => true
    end
    create_table(:commits) do
      primary_key :id
      String :sha, :null => false
      foreign_key :git_repo_id, :git_repos
      unique [:git_repo_id, :sha], :name => "sha_is_unique_per_repo"
      text :message
      foreign_key :user_id, :users
      datetime :date
      boolean :approved, :default => false
    end
    create_table(:files) do
      primary_key :id
      foreign_key :commit_id, :commits
    end
    create_table(:users) do
      primary_key :id
      String :name
      String :email
    end
  end
end

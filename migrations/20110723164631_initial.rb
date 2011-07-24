Sequel.migration do
  up do
    create_table(:commits) do
      primary_key :id
      string :sha, :null => false, :unique => true
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
      string :name
      string :email
    end
  end

  down do

  end
end

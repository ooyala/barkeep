Sequel.migration do
  up do
    create_table(:commits) do
      primary_key :id
      string :sha, :null => false, :unique => true
      boolean :approved, :default => false
    end
    create_table(:files) do
      primary_key :id
      foreign_key :commit_id, :commits
    end
  end

  down do

  end
end

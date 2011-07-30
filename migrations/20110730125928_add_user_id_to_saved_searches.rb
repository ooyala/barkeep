Sequel.migration do
  change do
    alter_table :saved_searches do
      add_foreign_key :user_id, :users
    end
  end
end

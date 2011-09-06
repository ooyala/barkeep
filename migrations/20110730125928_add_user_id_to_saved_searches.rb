require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  change do
    alter_table :saved_searches do
      add_foreign_key :user_id, :users, :key => :id
    end
  end
end

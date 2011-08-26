Sequel.migration do
  change do
    alter_table :saved_searches do
      add_column :branches, String
    end
  end
end

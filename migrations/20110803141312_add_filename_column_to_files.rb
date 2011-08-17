Sequel.migration do
  change do
    alter_table :files do
      add_column :filename, String
      add_index [:filename]
    end
  end
end

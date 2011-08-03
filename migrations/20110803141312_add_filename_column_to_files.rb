Sequel.migration do
  change do
    alter_table :files do
      add_column :filename, :string
      add_index [:filename]
    end
  end
end

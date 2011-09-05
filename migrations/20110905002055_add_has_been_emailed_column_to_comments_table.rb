require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  change do
    add_column :comments, :has_been_emailed, TrueClass, :default => 0
    add_index :comments, [:has_been_emailed, :created_at]
  end
end

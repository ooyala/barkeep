require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  change do
    add_column :saved_searches, :unapproved_only, TrueClass, :default => false
  end
end

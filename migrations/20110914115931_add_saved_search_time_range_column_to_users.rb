require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    add_column :users, :saved_search_time_period, Integer, :default => 7, :null => false # in days.
  end

  down do
    remove_column :users, :saved_search_time_period
  end
end

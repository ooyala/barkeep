require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  up do
    add_column :users, :review_list_order, String
  end

  down do
    drop_column :users, :review_list_order
  end
end

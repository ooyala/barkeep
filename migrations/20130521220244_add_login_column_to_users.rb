require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  up do
    alter_table(:users) {
	add_column :login, String
        add_index :login, :unique => true, :name => "login_is_unique_per_user"
    }
    run 'UPDATE users SET login=email'
  end

  down do
    alter_table(:users) {
      drop_index :login, :name => "login_is_unique_per_user"
      drop_column :login
    }
  end
end

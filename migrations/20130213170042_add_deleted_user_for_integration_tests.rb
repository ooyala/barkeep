require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"
require "time"

Sequel.migration do
  up do
    self[:users].insert(:name => "Deleted user", :email => "deleted_for_tests@example.com",
                      :deleted_at => Time.parse("2013-01-02"))
  end

  down do
    self[:users].filter(:email => "deleted_for_tests@example.com").delete
  end
end

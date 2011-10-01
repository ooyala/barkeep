# Creates a user which we can use during our integration tests.
require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    DB[:users].insert(:name => "Integration test", :email => "integration_test@example.com",
        :stats_time_range => "month", :saved_search_time_period => 7)
  end

  down do
    DB[:users].filter(:email => "integration_test@example.com").delete
  end
end

require "./" + File.join(File.dirname(__FILE__), "migration_helper")

# Creating a default user so we can assume there's a user logged in, for now.
Sequel.migration do
  up do
    self[:users].insert(:name => "demo", :email => "demo@demo.com")
  end

  down do
    self[:users].filter(:email => "demo@demo.com").delete
  end
end

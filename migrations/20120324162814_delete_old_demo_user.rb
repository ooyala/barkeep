require "bundler/setup"
require "pathological"
require "migrations/migration_helper.rb"

Sequel.migration do
  up do
    # We created this user in the migration "20110730130858_create_a_default_user.rb". We no longer need it
    # now that we have real user accounts and proper login support.
    self[:users].filter(:email => "demo@demo.com").delete
  end
end

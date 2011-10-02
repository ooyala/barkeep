# This table is no longer needed since we're managing jobs with Resque.
require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    drop_table :background_jobs
  end

  down do
    # no going back.
  end
end

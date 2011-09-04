require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    create_table :background_jobs do
      primary_key :id
      String :job_type

      String :params, :size => 2048 # The JSON representation of the job's parameters.
      DateTime :created_at

      index :job_type
    end
  end

  down do
    drop_table :background_jobs
  end
end

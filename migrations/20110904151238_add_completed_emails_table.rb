require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    create_table :completed_emails do
      primary_key :id
      # Either "success" or "failure"
      String :result, :size => 16
      String :to, :size => 512
      String :subject, :size => 128
      DateTime :created_at
      String :failure_reason, :size => 256
      String :comment_ids, :size => 256

      index [:result, :created_at]
    end
  end

  down do
    drop_table :completed_emails
  end
end

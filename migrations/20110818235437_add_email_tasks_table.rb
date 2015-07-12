require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    create_table(:email_tasks) do
      primary_key :id
      DateTime :created_at
      DateTime :last_attempted

      String :to, :size => 256
      String :subject, :size => 256
      text :body

      String :failure_reason, :size => 1024
    end
  end

  down do
    drop_table(:email_tasks)
  end
end

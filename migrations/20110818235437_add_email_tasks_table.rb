Sequel.migration do
  up do
    create_table(:email_tasks) do
      primary_key :id
      datetime :created_at
      datetime :last_attempted

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

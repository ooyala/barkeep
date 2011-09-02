Sequel.migration do
  change do
    add_column :email_tasks, :commit_id, Integer
    # Delete any outstanding EmailTasks in your database. They're no good without a commit_id.
    DB[:email_tasks].delete
  end
end

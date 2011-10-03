require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    alter_table(:saved_searches) do
      add_column :email_commits, TrueClass, :default => false
      # Note that this is true by default. We assume you'll want to see comments related to your saved search.
      add_column :email_comments, TrueClass, :default => true
    end

    # This column was never used and is superceded by the two new columns above.
    drop_column :saved_searches, :email_changes
  end

  down do
    drop_column :saved_searches, :email_commits
    drop_column :saved_searches, :email_comments

    alter_table(:saved_searches) do
      add_column :email_changes, TrueClass, :default => false
    end
  end
end

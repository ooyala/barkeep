Sequel.migration do
  up do
    create_table(:saved_searches) do
      primary_key :id
      datetime :created_at
      boolean :email_changes, :default => false
    end

    # A saved search consists of one or more search filters.
    create_table(:search_filters) do
      primary_key :id
      foreign_key :saved_search_id, :saved_searches
      # Filter types are things like "author", "directory".
      string :filter_type
      # The filter value will be the value of the search, e.g. "dmac" if searching for commits by dmac.
      strign :filter_value
    end
  end

  down do
    drop_table(:saved_searches)
    drop_table(:search_filters)
  end
end

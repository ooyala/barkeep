Sequel.migration do
  up do
    add_column :commits, :approved_at, DateTime
  end

  down do
    remove_column :commits, :approved_at, DateTime
  end
end

require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
		alter_table(:users) do
			add_column :stats_time_range, String, :default => "month"
		end
  end

  down do
		alter_table(:users) do
			drop_column :stats_time_range
		end
  end
end

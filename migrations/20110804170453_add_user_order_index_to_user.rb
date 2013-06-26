require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    alter_table :saved_searches do
      add_column :user_order, Integer
    end

    # Keep the current ordering (created_at)
    self[:users].each do |user|
      self[:saved_searches].filter(:user_id => user[:id]).order(:created_at).each_with_index do |search, i|
        self[:saved_searches].filter(:id => search[:id]).update(:user_order => i)
      end
    end

    alter_table :saved_searches do
      set_column_allow_null :user_order, false
      add_index [:user_id, :user_order]
    end
  end

  down do
    alter_table :saved_searches do
      drop_index [:user_id, :user_order]
      drop_column :user_order
    end
  end
end

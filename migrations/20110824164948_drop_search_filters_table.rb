require "./" + File.join(File.dirname(__FILE__), "migration_helper")

Sequel.migration do
  up do
    drop_table :search_filters
  end

  down do
    raise "HAHA SUCKA AIN'T NO GOIN BACK"
  end
end

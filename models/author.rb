class Author < Sequel::Model
  # This is really one_to_one, but Sequel requires the table containing the foreign key to be many_to_one.
  many_to_one :user
end

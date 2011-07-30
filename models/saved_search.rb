# A saved search represents a list of commits, some read and some unread.
class SavedSearch < Sequel::Model
  one_to_many :search_filters
end

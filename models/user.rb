# A logged-in user can comment and have their view preferences save.d
#
# Fields:
#  - email
#  - username
class User < Sequel::Model
  one_to_many :saved_searches
end
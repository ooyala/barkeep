# A logged-in user can comment and have their view preferences saved.
#
# Fields:
#  - email
#  - username
class User < Sequel::Model
  one_to_many :saved_searches, :order => [:created_at.desc]
end
#A single comit
class Commit < Sequel::Model
  many_to_one :users
  one_to_many :files
  one_to_many :comments
end

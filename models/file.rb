#A file in a commit
class File < Sequel::Model
  many_to_one :commits
  one_to_many :comments
end

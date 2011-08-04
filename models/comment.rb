#A comment in a commit
class Comment < Sequel::Model
  many_to_one :users
  many_to_one :files
  many_to_one :commits
end

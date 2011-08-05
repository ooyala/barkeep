#A comment in a commit
class Comment < Sequel::Model
  VERSION_BEFORE = "before"
  VERSION_AFTER = "after"

  many_to_one :user
  many_to_one :commit_file
  many_to_one :commit
end

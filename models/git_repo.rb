class GitRepo < Sequel::Model
  one_to_many :commits
  add_association_dependencies :commits => :destroy
end

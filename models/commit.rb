#A single comit
class Commit < Sequel::Model
  many_to_one :users
  one_to_many :commit_files
  one_to_many :comments

  #list of general comments for this commit
  def commit_comments
    self.comments.where(:commit_file_id => nil, :line_number => nil)
  end
end

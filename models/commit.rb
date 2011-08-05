#A single comit
class Commit < Sequel::Model
  many_to_one :user
  one_to_many :commit_files
  one_to_many :comments

  #list of general comments for this commit
  def commit_comments
    comments_dataset.filter(:commit_id => id, :commit_file_id => nil, :line_number => nil).order(:created_at).all
  end
end

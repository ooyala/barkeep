#A file in a commit
class CommitFile < Sequel::Model
  many_to_one :commits
  one_to_many :comments

    #list of general comments for this file
  def file_comments
    self.comments.filter(:line_number => nil)
  end

  #list of comments on individual lines
  def line_comments
    self.comments.exclude(:line_number => nil).order(:line_number)
  end
end

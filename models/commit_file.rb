#A file in a commit
class CommitFile < Sequel::Model
  many_to_one :commit
  one_to_many :comments

  add_association_dependencies :comments => :destroy

    #list of general comments for this file
  def file_comments
    comments_dataset.filter(:line_number => nil).order(:created_at).all
  end

  #list of comments on individual lines
  def line_comments
    comments_dataset.exclude(:line_number => nil).order(:line_number, :created_at).all
  end
end

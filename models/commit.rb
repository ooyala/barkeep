# Columns:
# - approved_at: when the commit was approved.
# - approved_by_user_id: the most recent user to approve the commit.
class Commit < Sequel::Model
  many_to_one :user
  one_to_many :commit_files
  one_to_many :comments
  many_to_one :approved_by_user, :class => User

  # TODO(philc): There should be a way to get a grit_commit from this object.

  def commit_comments
    comments_dataset.filter(:commit_id => id, :commit_file_id => nil, :line_number => nil).
        order(:created_at).all
  end

  def approved?() !approved_by_user_id.nil? end

  def approve(user)
    self.approved_at = Time.now
    self.approved_by_user_id = user.id
    save
  end

  def disapprove
    self.approved_at = nil
    self.approved_by_user_id = nil
    save
  end
end

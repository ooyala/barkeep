class ReviewRequest < Sequel::Model
  many_to_one :commit
  many_to_one :requester_user, :class => User
  many_to_one :reviewer_user, :class => User

  def self.commits_with_uncompleted_reviews(user_id)
    uncompleted = ReviewRequest.filter(:reviewer_user_id => user_id, :completed_at => nil).
      group_by(:commit_id).all
    commits = uncompleted.map do |review|
      grit_commit = MetaRepo.instance.grit_commit(review.commit.git_repo.name, review.commit.sha)
      next unless grit_commit
      grit_commit
    end
    commits.reject!(&:nil?)
    commits
  end
end

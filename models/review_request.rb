class ReviewRequest < Sequel::Model
  many_to_one :commit
  many_to_one :requester_user, :class => User
  many_to_one :reviewer_user, :class => User

  def self.get_grit_commits(reviews)
    grit_commits = reviews.map do |review|
      grit_commit = MetaRepo.instance.grit_commit(review.commit.git_repo.name, review.commit.sha)
      next unless grit_commit
      grit_commit
    end
    grit_commits.reject(&:nil?)
  end

  def self.commits_with_uncompleted_reviews(user_id)
    uncompleted = ReviewRequest.filter(:reviewer_user_id => user_id, :completed_at => nil).
      group_by(:commit_id).all
    get_grit_commits(uncompleted)
  end

  def self.recently_reviewed_commits(user_id)
    recently_reviewed = ReviewRequest.filter(:reviewer_user_id => user_id).
        exclude(:completed_at => nil).
        group_by(:commit_id).
        reverse_order(:completed_at).limit(5).all
    get_grit_commits(recently_reviewed)
  end

  def self.requests_from_me(user_id)
    uncompleted = ReviewRequest.filter(:requester_user_id => user_id, :completed_at => nil).
      group_by(:commit_id).all
    get_grit_commits(uncompleted)
  end

  def self.complete_requests(commit_id)
    ReviewRequest.filter(:commit_id => commit_id).update(:completed_at => Time.now.utc)
  end
end

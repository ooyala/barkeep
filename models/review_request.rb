class ReviewRequest < Sequel::Model
  many_to_one :commit
  many_to_one :requester_user, :class => User
  many_to_one :reviewer_user, :class => User

  def self.create_review_list_entries(reviews)
    entries = []
    reviews.each do |review|
      grit_commit = MetaRepo.instance.grit_commit(review.commit.git_repo.name, review.commit.sha)
      next unless grit_commit
      entry = ReviewListEntry.new(grit_commit)
      entry.review_request = review
      entries << entry
    end
    entries
  end

  def self.commits_with_uncompleted_reviews(user_id)
    uncompleted = ReviewRequest.filter(:reviewer_user_id => user_id, :completed_at => nil).
      group_by(:commit_id).all
    create_review_list_entries(uncompleted)
  end

  def self.recently_reviewed_commits(user_id)
    recently_reviewed = ReviewRequest.filter(:reviewer_user_id => user_id).
        exclude(:completed_at => nil).
        group_by(:commit_id).
        reverse_order(:completed_at).limit(5).all
    create_review_list_entries(recently_reviewed)
  end

  def self.requests_from_me(user_id)
    uncompleted = ReviewRequest.filter(:requester_user_id => user_id, :completed_at => nil).
      group_by(:commit_id).all
    create_review_list_entries(uncompleted)
  end

  def self.complete_requests(commit_id)
    ReviewRequest.filter(:commit_id => commit_id).update(:completed_at => Time.now.utc)
  end
end

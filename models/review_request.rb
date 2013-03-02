class ReviewRequest < Sequel::Model
  many_to_one :commit
  many_to_one :requester_user, :class => User
  many_to_one :reviewer_user, :class => User

  PAGE_SIZE = 8

  def self.create_review_list_entries(reviews, token)
    entries = []
    reviews.each do |review|
      grit_commit = MetaRepo.instance.grit_commit(review.commit.git_repo.name, review.commit.sha)
      next unless grit_commit
      entry = ReviewListEntry.new(grit_commit)
      entry.review_request = review
      entries << entry
    end
    ReviewList.new(entries, token)
  end

  def self.commits_with_uncompleted_reviews(user_id, token = nil, direction = "next", page_size = PAGE_SIZE)
    token = ReviewList.make_token(0, 0, 0, false) if token.nil?
    dataset = ReviewRequest.filter(:reviewer_user_id => user_id, :completed_at => nil).group_by(:commit_id)
    reviews, token = Commit.paginate_dataset(dataset, [:id], token, direction, page_size)
    create_review_list_entries(reviews, token)
  end

  def self.recently_reviewed_commits(user_id, token = nil, direction = "next", page_size = PAGE_SIZE)
    token = ReviewList.make_token(0, [0, 0], [0, 0], false) if token.nil?
    dataset = ReviewRequest.filter(:reviewer_user_id => user_id).exclude(:completed_at => nil).
        group_by(:commit_id)
    reviews, token = Commit.paginate_dataset(dataset, [[:completed_at, :desc], :id],
        token, direction, page_size)
    create_review_list_entries(reviews, token)
  end

  def self.requests_from_me(user_id, token = nil, direction = "next", page_size = PAGE_SIZE)
    token = ReviewList.make_token(0, 0, 0, false) if token.nil?
    dataset = ReviewRequest.filter(:requester_user_id => user_id, :completed_at => nil).group_by(:commit_id)
    reviews, token = Commit.paginate_dataset(dataset, [:id], token, direction, page_size)
    create_review_list_entries(reviews, token)
  end

  def self.complete_requests(commit_ids)
    ReviewRequest.filter(:commit_id => commit_ids).update(:completed_at => Time.now.utc)
  end
end

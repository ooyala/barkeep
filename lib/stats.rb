# TODO(dmac): Some of these calls could get really expensive as the size
# of our repos grow. We might need to eventually persist some of these stats
# in our db.
def unreviewed_commits
  Commit.all.select { |commit| commit.comments.empty? }
end

def reviewed_without_lgtm_commits
  Commit.filter(:approved_by_user_id => nil).all.reject { |commit| commit.comments.empty? }
end

def lgtm_commits
  Commit.filter("approved_by_user_id IS NOT NULL").all
end

# TODO(dmac): Maybe limit this to chattiest commits in the last few days?
# That is probably a more interesting metric.
def chatty_commits(repo, num = 10)
  commit_shas_and_counts = Commit.join(:comments, :commit_id => :id).
      group_and_count(:commits__sha).order(:count.desc).limit(num).all
  commits_and_counts = commit_shas_and_counts.map do |sha_and_count|
    [repo.commits(sha_and_count[:sha], 1).first, sha_and_count[:count]]
  end
  commits_and_counts
end

def top_reviewers(num = 10)
  user_ids_and_counts = User.join(:comments, :user_id => :id).
      group_and_count(:users__id).order(:count.desc).limit(num).all
  users_and_counts = user_ids_and_counts.map do |id_and_count|
    [User[id_and_count[:id]], id_and_count[:count]]
  end
end

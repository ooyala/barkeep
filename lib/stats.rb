require "lib/meta_repo.rb"

# TODO(dmac): Some of these calls could get really expensive as the size
# of our repos grow. We might need to eventually persist some of these stats
# in our db.
#
# TODO(dmac): These currently aggregate stats across all repos.
# We should expose /stats/:repo_name drill-down.

module Stats
  def self.unreviewed_commits
    Commit.all.select { |commit| commit.comments.empty? }
  end

  def self.reviewed_without_lgtm_commits
    Commit.filter(:approved_by_user_id => nil).all.reject { |commit| commit.comments.empty? }
  end

  def self.lgtm_commits
    Commit.filter("approved_by_user_id IS NOT NULL").all
  end

  # TODO(dmac): Maybe limit this to chattiest commits in the last few days?
  # That is probably a more interesting metric.
  def self.chatty_commits(num = 10)
    dataset = Commit.
        join(:comments, :commit_id => :id).
        join(:git_repos, :id => :commits__git_repo_id).
        group_and_count(:commits__sha, :git_repos__name___repo).order(:count.desc).limit(num)
    commits_sha_repo_count = dataset.all
    commits_and_counts = commits_sha_repo_count.map do |sha_repo_count|
      [MetaRepo.grit_commit(sha_repo_count[:repo], sha_repo_count[:sha]), sha_repo_count[:count]]
    end
    commits_and_counts
  end

  def self.top_reviewers(num = 10)
    user_ids_and_counts = User.join(:comments, :user_id => :id).
        group_and_count(:users__id).order(:count.desc).limit(num).all
    users_and_counts = user_ids_and_counts.map do |id_and_count|
      [User[id_and_count[:id]], id_and_count[:count]]
    end
  end
end

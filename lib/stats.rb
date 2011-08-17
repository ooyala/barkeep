def unreviewed_commits
  Commit.all.select { |commit| commit.comments.empty? }
end

def reviewed_without_lgtm_commits
  Commit.filter(:approved_by_user_id => nil).all.reject { |commit| commit.comments.empty? }
end

def lgtm_commits
  Commit.filter("approved_by_user_id IS NOT NULL").all
end

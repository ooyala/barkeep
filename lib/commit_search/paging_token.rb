# NOTE(caleb): (To myself for when I'm awake) -- A paging token is (timestamp, repo_name, sha).
# It is necessary to know the commit (identified by (repo, sha)) because there's lots of collision in the
# timestamps (for example, when you rebase). So, to know the next (or previous) set of commits to show you, we
# need to know the timestamp AND the commit, and we can go look up the next N commits after that timestamp
# and then trim out the ones that appear before the commit listed in the token.

class PagingToken
  attr_accessor :timestamp, :repo_name, :sha
  def initialize(timestamp, repo_name, sha)
    @timestamp = timestamp
    @repo_name = repo_name
    @sha = sha
  end

  # Presumably "/" is a good separator because it won't appear in repo_name
  def to_s
    "#{@timestamp}/#{@repo_name}/#{@sha}"
  end

  def self.from_s(s)
    timestamp, repo_name, sha = s.split("/")
    PagingToken.new timestamp.to_i, repo_name, sha
  end
end

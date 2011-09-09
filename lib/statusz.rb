# This reads out some metadata about the current running version of Barkeep from files written at deploy time.
# In particular, git information such as the current HEAD, current branch, and user info are written to
# "git_deploy_info.txt", and all the commits reachable from HEAD (that is, the set of all commits contained in the
# deploy) are written to "all_commits.txt".
#
# This information is exposed through the /statusz route.

module Statusz
  def self.summary_info
    File.read File.join(File.dirname(__FILE__), "../git_deploy_info.txt")
  end

  def self.commit_info(sha_part)
    return "Need more than '#{sha_part}' to search." unless sha_part.size > 4
    all_commits_file = File.join(File.dirname(__FILE__), "../all_commits.txt")
    matching_commits = `cat #{all_commits_file} | grep "^#{sha_part}"`
    return "No matching commits" if matching_commits.empty?
    "Matching commits:\n" << matching_commits
  end
end

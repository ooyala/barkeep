require "addressable/uri"
require "digest/sha1"
require "resque_jobs/clone_new_repo"

module Api
  def add_repo(url)
    raise "This is not a valid URL." unless Addressable::URI.parse(url)
    repo_name = File.basename(url, ".*")
    repo_path = File.join(REPOS_ROOT, repo_name)
    raise "There is already a folder named \"#{repo_name}\" in #{REPOS_ROOT}." if File.exists?(repo_path)
    Resque.enqueue(CloneNewRepo, repo_name, url)
  end

  # Generate a random API key or API secret for a user.
  def self.generate_user_key() Digest::SHA1.hexdigest(rand(1000000).to_s + Time.now.to_s) end
end

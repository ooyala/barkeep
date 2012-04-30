require "addressable/uri"
require "base64"
require "digest/sha1"
require "openssl"
require "uri"

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
  def self.generate_user_key()
    Base64.encode64(Digest::SHA1.hexdigest(rand(2**256).to_s)).strip.sub("==", "")
  end

  # Generate a signature from a request and a user's api secret. This is used in authenticating an API
  # request. The user of this method needs to verify that there is a timestamp, that it is correct, check the
  # api_key, etc.
  # - request: Sinatra request
  # - api_secret: The user's api secret from the DB
  def self.generate_request_signature(request, api_secret)
    canonical_request_string = "#{request.env["REQUEST_METHOD"]} #{request.path}"
    ordered_keys = request.params.keys.reject { |k| k == "signature" }.sort
    # Sinatra has already url-decoded the query-string parameters at this point, so re-encode them.
    canonical_query_string = ordered_keys.map { |key| "#{key}=#{URI.encode(request.params[key])}" }.join("&")
    canonical_request_string << "?#{canonical_query_string}" unless canonical_query_string.empty?
    OpenSSL::HMAC.hexdigest("sha1", api_secret, canonical_request_string)
  end
end

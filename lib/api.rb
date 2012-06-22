require "addressable/uri"
require "base64"
require "securerandom"
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
  def self.generate_user_key() SecureRandom.uuid.gsub("-", "") end

  # Generate a signature from a request and a user's api secret. This is used in authenticating an API
  # request. The user of this method needs to verify that there is a timestamp, that it is correct, check the
  # api_key, etc. See https://github.com/ooyala/barkeep/wiki/REST-API for more information about request
  # signing.
  # - request: Sinatra request
  # - api_secret: The user's api secret from the DB
  def self.generate_signature_from_request(request, api_secret)
    params_without_signature = request.params.reject { |key, value| key == "signature" }
    generate_signature(request.env["REQUEST_METHOD"], request.path, params_without_signature, api_secret)
  end

  # Generate a signature from an http request (method, path, querystring parameters) and api secret. The
  # parameters should be a hash, and the values should not already by url-encoded.
  def self.generate_signature(http_method, path, params, api_secret)
    canonical_request_string = "#{http_method.to_s.upcase} #{path}"
    ordered_keys = params.keys.sort
    canonical_query_string = ordered_keys.map { |key| "#{key}=#{URI.encode(params[key])}" }.join("&")
    canonical_request_string << "?#{canonical_query_string}" unless canonical_query_string.empty?
    OpenSSL::HMAC.hexdigest("sha1", api_secret, canonical_request_string)
  end
end

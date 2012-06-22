# API to allow for a RESTful interface to Barkeep.
require "time"

require "lib/api"

class BarkeepServer < Sinatra::Base
  include Api

  helpers do
    def api_error(status, message)
      halt status, { "error" => message }.to_json
    end
  end

  # API routes that don't require authentication
  AUTHENTICATION_WHITELIST_ROUTES = ["/api/commits/"]
  # API routes that require admin
  ADMIN_ROUTES = ["/api/add_repo"]
  # How out of date an API call may be before it is rejected
  ALLOWED_API_STALENESS_MINUTES = 5

  before "/api/*" do
    content_type :json
    next if AUTHENTICATION_WHITELIST_ROUTES.any? { |route| request.path =~ /^#{route}/ }
    user = ensure_properly_signed(request, params)
    if ADMIN_ROUTES.any? { |route| request.path =~ /^#{route}/ }
      api_error 403, "Admin only." unless user.admin?
    end
    self.current_user = user
  end

  post "/api/add_repo" do
    ensure_required_params :url
    begin
      add_repo params[:url]
    rescue RuntimeError => e
      api_error 400, e.message
    end
    [202, "Repo #{repo_name} is scheduled to be cloned."]
  end

  post "/api/comment" do
    ensure_required_params :repo_name, :sha, :text
    begin
      create_comment(*[:repo_name, :sha, :filename, :line_number, :text].map { |f| params[f] })
    rescue RuntimeError => e
      api_error 400, e.message
    end
    nil
  end

  get "/api/commits/:repo_name/:sha" do
    fields = params[:fields] ? params[:fields].split(",") : nil
    begin
      commit = Commit.prefix_match params[:repo_name], params[:sha]
    rescue RuntimeError => e
      api_error 404, e.message
    end
    format_commit_data(commit, params[:repo_name], fields).to_json
  end

  # NOTE(caleb): Large GET requests are rejected by the Ruby web servers we use. (Unicorn, in particular,
  # doesn't seem to like paths > 1k and rejects them silently.) Hence, to batch-request commit data, we must
  # use a POST.
  post "/api/commits/:repo_name" do
    shas = params[:shas].split(",")
    fields = params[:fields] ? params[:fields].split(",") : nil
    commits = {}
    shas.each do |sha|
      begin
        commit = Commit.prefix_match params[:repo_name], sha
      rescue RuntimeError => e
        api_error 404, e.message
      end
      commits[commit.sha] = format_commit_data(commit, params[:repo_name], fields)
    end
    commits.to_json
  end

  private

  def format_commit_data(commit, repo_name, fields)
    approver = commit.approved? ? commit.approved_by_user : nil
    commit_data = {
      :approved => commit.approved?,
      :approved_by => commit.approved? ? "#{approver.name} <#{approver.email}>" : nil,
      :approved_at => commit.approved? ? commit.approved_at.to_i : nil,
      :comment_count => commit.comment_count,
      :link => "http://#{BARKEEP_HOSTNAME}/commits/#{params[:repo_name]}/#{commit.sha}"
    }
    fields ? commit_data.select { |key, value| fields.include? key.to_s } : commit_data
  end

  # Check that an authenticated request is properly formed and correctly signed. Returns the user if
  # everything is OK.
  def ensure_properly_signed(request, params)
    api_key = params[:api_key]
    api_error 400, "No API key provided." unless api_key
    user = User[:api_key => api_key]
    api_error 400, "Bad API key provided." unless user
    api_error 403, "The demo user is not allowed to make API requests." if user.demo?
    ensure_required_params :timestamp, :signature
    api_error 400, "Bad timestamp." unless params[:timestamp] =~ /^\d+$/
    timestamp = Time.at(params[:timestamp].to_i) rescue Time.at(0)
    staleness = (Time.now.to_i - timestamp.to_i) / 60.0
    if staleness < 0
      api_error 400, "Bad timestamp."
    elsif staleness > ALLOWED_API_STALENESS_MINUTES
      api_error 400, "Timestamp too stale."
    end
    unless Api.generate_signature_from_request(request, user.api_secret) == params[:signature]
      api_error 400, "Bad signature."
    end
    user
  end
end

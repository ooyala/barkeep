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
  AUTHENTICATION_WHITELIST_ROUTES = ["/api/commits/", "/api/stats"]
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

  get "/api/stats" do
    since = params[:since] ? params[:since] : Time.now - 60 * 60 * 24 * 30
    format_stats(since).to_json
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

  def format_user_data(user_ids_and_counts)
    user_ids_and_counts.map do |id_and_count|
      {:count => id_and_count[1],
        :name => id_and_count[0].name,
        :email => id_and_count[0].email}
    end
  end

  def format_stats(since)
    dataset = Commit.
      join(:comments, :commit_id => :id).
      filter("`comments`.`created_at` > ?", since).
      join(:git_repos, :id => :commits__git_repo_id).
      group_and_count(:commits__sha, :git_repos__name___repo).order(:count.desc).limit(10)
    chatty_commits = dataset.all
    chatty_commits.map! do |commit|
      {:sha => commit.sha,
        :comment_count => commit[:count],
        :repo_name => commit[:repo]
        }
    end
    chatty_commits.map! do |commit|
      commit_obj = Commit.prefix_match commit[:repo_name], commit[:sha]
      {:sha => commit_obj.sha,
        :comment_count => commit_obj.comment_count,
        :message => commit_obj.message,
        :repo_name => commit[:repo_name],
        :approved => commit_obj.approved?}
    end
    data = {"num_commits" => Stats.num_commits(since),
            "num_unreviewed_commits" => Stats.num_unreviewed_commits(since),
            "num_reviewed_without_lgtm_commits" => Stats.num_reviewed_without_lgtm_commits(since),
            "num_lgtm_commits" => Stats.num_lgtm_commits(since),
            "chatty_commits" => chatty_commits,
            "top_reviewers" => format_user_data(Stats.top_reviewers(since)),
            "top_approvers" => format_user_data(Stats.top_approvers(since))}
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

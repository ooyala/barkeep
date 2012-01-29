# API to allow for a RESTful interface to Barkeep.

class Barkeep < Sinatra::Base
  # TODO(caleb/dmac): API authentication before filter. Need to assign users an API key and sign requests.

  # NOTE(dmac): This can tie up the server if the checked out repo
  # is very large. The task could be backgrounded, but the server's instance
  # of MetaRepo will need to be reloaded *after* the background job finishes.
  post "/api/add_repo" do
    halt 400 unless params[:url]
    halt 400, "Invalid url" unless Addressable::URI.parse(params[:url])
    repo_name = File.basename(params[:url], ".*")
    repo_path = File.join(REPOS_ROOT, repo_name)
    Grit::Git.new(repo_path).clone({}, params[:url], repo_path)
    MetaRepo.instance.load_repos
  end

  get "/api/commits/:repo_name/:sha" do
    begin
      commit = Commit.prefix_match params[:repo_name], params[:sha]
    rescue RuntimeError => e
      next [404, { :message => e.message }.to_json]
    end
    content_type :json
    approver = commit.approved? ? commit.approved_by_user : nil
    {
      :approved => commit.approved?,
      :approved_by => commit.approved? ? "#{approver.name} <#{approver.email}>" : nil,
      :approved_at => commit.approved? ? commit.approved_at.to_i : nil,
      :comment_count => commit.comment_count,
      :link => "http://#{BARKEEP_HOSTNAME}/commits/#{params[:repo_name]}/#{commit.sha}"
    }.to_json
  end
end

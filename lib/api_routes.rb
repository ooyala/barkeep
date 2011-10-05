# API to allow for a RESTful interface to Barkeep.

class Barkeep < Sinatra::Base
  # TODO(caleb/dmac): API authentication before filter. Need to assign users an API key and sign requests.

  # NOTE(dmac): This can tie up the server if the checked out repo
  # is very large. The task could be backgrounded, but the server's instance
  # of MetaRepo will need to be reloaded *after* the background job finishes.
  post "/api/add_repo" do
    halt 400 unless params[:url]
    # We have to be careful of using a system call here.
    # Note this attack: "url=http://fake.com; rm -fr ./*"
    # Grit provides no way to check out a repository, which is why the system call is used.
    # One alternative might be https://github.com/schacon/ruby-git
    halt 400, "Invalid url" unless Addressable::URI.parse(params[:url])
    system("cd #{REPOS_ROOT} && git clone #{params[:url]}")
    # NOTE(dmac): We may want to handle cloning empty repos
    # by deleting the empty directory.
    MetaRepo.instance.load_repos
    "OK"
  end

  get "/api/commits/:repo_name/:sha" do
    commit = MetaRepo.instance.db_commit params[:repo_name], params[:sha]
    content_type :json
    next [404, { :message => "Bad repo name or commit not found." }.to_json] unless commit
    approver = commit.approved? ? commit.approved_by_user : nil
    {
      :approved => commit.approved?,
      :approved_by => commit.approved? ? "#{approver.name} <#{approver.email}>" : nil,
      :approved_at => commit.approved? ? commit.approved_at.to_i : nil,
      :comment_count => commit.comment_count,
      :link => "http://#{BARKEEP_HOSTNAME}/commits/#{params[:repo_name]}/#{params[:sha]}"
    }.to_json
  end
end


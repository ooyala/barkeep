# API to allow for a RESTful interface to Barkeep.
require "lib/api"

class Barkeep < Sinatra::Base
  include Api
  # TODO(caleb/dmac): API authentication before filter. Need to assign users an API key and sign requests.

  post "/api/add_repo" do
    halt 400, "'url' is required." if (params[:url] || "").strip.empty?
    begin
      add_repo params[:url]
    rescue RuntimeError => e
      halt 400, e.message
    end
    [204, "Repo #{repo_name} is scheduled to be cloned."]
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

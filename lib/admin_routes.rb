#
# Sinatra routes which implement the Admin pages.
#
require "lib/api"
require "resque_jobs/delete_repo"
require "fileutils"
require "sinatra/base"
require "methodchain"

class BarkeepServer < Sinatra::Base
  include Api

  before "/admin*" do
    unless current_user.admin?
      message = "You do not have permission to view this admin page."
      message += " <a href='/signin'>Sign in</a>." unless logged_in?
      halt 400, message
    end
  end

  # A page to help keep track of Barkeep's data models and background processes. Also see the Resque dashboard
  # (/resque).
  get "/admin/?" do
    admin_erb :index
  end

  get "/admin/diagnostics?" do
    admin_erb :diagnostics, :locals => {
      :most_recent_commit => Commit.order(:id.desc).first,
      :most_recent_comment => Comment.order(:id.desc).first,
      :repos => MetaRepo.instance.repos.map(&:name),
      :failed_email_count => CompletedEmail.filter(:result => "failure").count,
      :recently_failed_emails =>
          CompletedEmail.filter(:result => "failure").order(:created_at.desc).limit(10).all,
      :pending_comments => Comment.filter(:has_been_emailed => false).order(:id.asc).limit(10).all,
      :pending_comments_count => Comment.filter(:has_been_emailed => false).count,
    }
  end

  get "/admin/users/?" do
    # Don't show deleted users or the demo user.
    users = User.filter(:deleted_at => nil).exclude(:permission => "demo").order_by(:name).all
    admin_erb :manage_users, :locals => { :users => users }
  end

  post "/admin/users/update_permissions" do
    user = User.first(:id => params[:user_id])
    halt 400 unless user
    halt 400 unless ["normal", "admin"].include? params[:permission]
    user.permission = params[:permission]
    user.save
    nil
  end

  delete "/admin/users/:user_id" do
    user = User.first(:id => params[:user_id])
    halt 400 unless user
    # Delete all the user's saved searches
    SavedSearch.where(:user_id => user.id).delete
    # Disassociate any authors
    Author.where(:user_id => user.id).update(:user_id => nil)
    # Mark the user as deleted
    user.deleted_at = Time.now
    user.save
    nil
  end

  get "/admin/repos/?" do
    MetaRepo.instance.scan_for_new_repos
    # TODO(philc): Currently importing.
    git_repos = GitRepo.all.sort_by(&:name)
    repos_hashes = git_repos.map do |git_repo|
      grit_repo = MetaRepo.instance.get_grit_repo(git_repo.name)
      origin = begin
                 grit_repo.then { origin_url }
               rescue IndexError => e # If this repo is in a bad state after cloning
                 nil
               end
      {
        :name => git_repo.name,
        :exists_on_disk => !!grit_repo,
        :origin_url => origin,
        :newest_commit => git_repo.commits_dataset.order(:date.desc).first
      }
    end

    # Don't show git repos that don't actually exist in the repos directory, such as test repos.
    repos_hashes.reject! { |repo_hash| !repo_hash[:exists_on_disk] }

    log_directory = File.expand_path(File.join(File.dirname(__FILE__), "../log"))
    # NOTE(philc): Native ruby would be better, but I was too lazy to find a better solution.
    tail_log = Proc.new { |log_file| `tail -n 20 '#{File.join(log_directory, log_file)}' 2> /dev/null` }
    admin_erb :repos, :locals => {
      :repos_hashes => repos_hashes,
      :repos_being_cloned => repos_being_cloned,
      :clone_new_repo_log => tail_log.call("clone_new_repo.log"),
      :fetch_commits_log => tail_log.call("fetch_commits.log")
    }
  end

  # Schedules a Git repo to be cloned.
  #  - url
  post "/admin/repos/create_new_repo" do
    halt 400, "'url' is required." if (params[:url] || "").strip.empty?
    begin
      add_repo params[:url]
    rescue RuntimeError => e
      halt 400, e.message
    end
    nil
  end

  post "/admin/repos/delete_repo" do
    Resque.enqueue(DeleteRepo, params[:name])
    nil
  end

  # You can view log files from within the UI.
  get "/admin/log/:file_name" do
    next if params[:file_name].include?("..")
    content_type "text/plain"
    `tail -n 500 log/#{params[:file_name]}`
  end

  helpers do
    def admin_page_breadcrumb(display_name)
      %Q(<div id="adminBreadcrumb"><a href="/admin">Admin</a> &raquo; #{display_name}</div>)
    end
  end

  private

  def repos_being_cloned
    # Resque jobs look like: { "class"=>"CloneNewRepo", "args"=>["repo_name", "repo_url"] }
    jobs = Resque.peek("clone_new_repo", 0, 25)
    jobs.map { |job| job["args"][1] }
  end

  def admin_erb(view, view_params = {})
    # NOTE(philc): This use of nested Sinatra layouts is a little clunky. It's the best approach I could find.
    html_with_admin_layout = erb(:"admin/#{view}", { :layout => :"admin/layout" }.merge(view_params))
    erb html_with_admin_layout
  end
end

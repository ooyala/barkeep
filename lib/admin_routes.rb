#
# Sinatra routes which implement the Admin pages.
#
class Barkeep < Sinatra::Base
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
    # Don't show the demo user. It's confusing.
    users = User.filter("permission != 'demo'").order_by(:name).all
    erb :manage_users, :locals => { :users => users }
  end

  post "/admin/users/update_permissions" do
    # Don't allow a user to remove their own admin privileges, because then you can no longer use the
    # admin pages. It's a confusing experience.
    user = User.first(:id => params[:user_id])
    next if current_user == user
    halt 400 unless ["normal", "admin"].include? params[:permission]
    user.permission = params[:permission]
    user.save
    nil
  end

  helpers do
    def admin_page_breadcrumb(display_name)
      %Q(<div id="adminBreadcrumb">
          <a href="/admin">Admin</a> &raquo; #{display_name}
        </div>)
    end
  end

  private

  def admin_erb(view, view_params = {})
    # NOTE(philc): This use of nested Sinatra layouts is a little klunky. It's the best approach I could find.
    html_with_admin_layout = erb("admin/#{view}".to_sym, { :layout => :"admin/layout" }.merge(view_params))
    erb html_with_admin_layout
  end
end
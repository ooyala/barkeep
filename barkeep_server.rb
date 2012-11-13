require "bundler/setup"
require "pathological"

require "bourbon"
require "coffee-script"
require "methodchain"
require "nokogiri"
require "open-uri"
require "openid"
require "openid/extensions/ax"
require "openid/store/filesystem"
require "pinion"
require "pinion/sinatra_helpers"
require "redcarpet"
require "redis"
require "sass"
require "sinatra/base"
require "sinatra/reloader"
require "uglifier"

require "environment"
require "lib/ruby_extensions"
require "lib/git_helper"
require "lib/git_diff_utils"
require "lib/keyboard_shortcuts"
require "lib/meta_repo"
require "lib/pretty_date"
require "lib/script_environment"
require "lib/stats"
require "lib/statusz"
require "lib/string_helper"
require "lib/string_filter"
require "lib/filters"
require "lib/inspire"
require "lib/redis_manager"
require "lib/redcarpet_extensions"
require "lib/mustache_renderer"
require "resque_jobs/deliver_review_request_emails.rb"

NODE_MODULES_BIN_PATH = "./node_modules/.bin"
OPENID_AX_EMAIL_SCHEMA = "http://axschema.org/contact/email"
UNAUTHENTICATED_ROUTES = ["/signin", "/signout", "/inspire", "/statusz", "/api/"]
# NOTE(philc): Currently we let you see previews of individual commits and the code review stats without
# being logged in, as a friendly UX. When we flesh out our auth model, we should intentionally make this
# configurable.
UNAUTHENTICATED_PREVIEW_ROUTES = ["/commits/", "/stats"]


# OPENID_PROVIDERS is a string env variable. It's a comma-separated list of OpenID providers.
OPENID_PROVIDERS_ARRAY = OPENID_PROVIDERS.split(",")

class BarkeepServer < Sinatra::Base
  attr_accessor :current_user

  # Set up Pinion to manage static and compiled assets.
  set :pinion, Pinion::Server.new("/assets")
  configure do
    pinion.convert :scss => :css
    pinion.convert :coffee => :js
    pinion.watch "public"
    pinion.watch "#{Gem.loaded_specs["bourbon"].full_gem_path}/app/assets/stylesheets"

    # Set up asset bundles
    pinion.create_bundle :vendor_js, :concatenate_and_uglify_js, [
      "/vendor/jquery-1.7.min.js",
      "/vendor/jquery-ui-1.8.19.custom.min.js",
      "/vendor/jquery.json-2.2.min.js",
      "/vendor/jquery.tipsy.js",
      "/vendor/jquery.hotkeys.js"
    ]
    pinion.create_bundle :app_js, :concatenate_and_uglify_js, [
      "/coffee/constants.js",
      "/coffee/util.js",
      "/coffee/snippets.js"
    ]
    pinion.create_bundle :repo_app_js, :concatenate_and_uglify_js, ["/coffee/repos.js"]
    pinion.create_bundle :commit_app_js, :concatenate_and_uglify_js, ["/coffee/commit.js"]
    pinion.create_bundle :commit_vendor_js, :concatenate_and_uglify_js, [
      "/vendor/jquery.easing.1.3.js",
      "/vendor/mustache.js"
    ]
    pinion.create_bundle :commit_search_app_js, :concatenate_and_uglify_js, [
      "/coffee/smart_search.js",
      "/coffee/commit_search.js"
    ]
    pinion.create_bundle :commit_search_vendor_js, :concatenate_and_uglify_js, [
      "/vendor/jquery.easing.1.3.js"
    ]
    pinion.create_bundle :stats_app_js, :concatenate_and_uglify_js, ["/coffee/stats.js"]
    pinion.create_bundle :stats_vendor_js, :concatenate_and_uglify_js, [
      "/vendor/flot/jquery.flot.min.js",
      "/vendor/flot/jquery.flot.pie.min.js"
    ]
    pinion.create_bundle :user_settings_app_js, :concatenate_and_uglify_js, ["/coffee/user_settings.js"]
  end

  helpers Pinion::SinatraHelpers

  # Pinion will handle all static routes
  disable :static
  set :views, "views"
  enable :sessions

  raise "You must have an OpenID provider defined in OPENID_PROVIDERS." if OPENID_PROVIDERS.empty?

  configure :development do
    STDOUT.sync = true # Flush any output right away when running via Foreman.
    enable :logging
    set :show_exceptions, false
    set :dump_errors, false
    set :session_secret, COOKIE_SESSION_SECRET if defined?(COOKIE_SESSION_SECRET)

    GitDiffUtils.setup(RedisManager.redis_instance)

    error do
      # Show a more developer-friendly error page and stack traces.
      content_type "text/plain"
      error = request.env["sinatra.error"]
      message = ([error.class, error.message] + error.backtrace).join("\n")
      puts message
      message
    end

    register Sinatra::Reloader
    also_reload "lib/*.rb"
    also_reload "models/*.rb"
    also_reload "environment.rb"
    also_reload "resque_jobs/*.rb"
  end

  configure :test do
    set :show_exceptions, false
    set :dump_errors, false
    GitDiffUtils.setup(nil)
  end

  configure :production do
    set :logging, Logger::INFO
    set :session_secret, COOKIE_SESSION_SECRET if defined?(COOKIE_SESSION_SECRET)
    GitDiffUtils.setup(RedisManager.redis_instance)
  end

  helpers do
    def current_page_if_url(text) request.url.include?(text) ? "currentPage" : "" end

    def find_commit(repo_name, sha, zero_commits_ok)
      commit = MetaRepo.instance.db_commit(repo_name, sha)
      unless commit
        begin
          commit = Commit.prefix_match(repo_name, sha, zero_commits_ok)
        rescue RuntimeError => e
          halt 404, e.message
        end
      end
      commit
    end

    def ensure_required_params(*required_params)
      required_params.each do |param|
        unless params[param] && !params[param].strip.empty?
          message = "Missing required parameter '{param}'."
          if content_type == "application/json"
            halt 400, { :error => message }.to_json
          else
            halt 400, message
          end
        end
      end
    end
  end

  before do
    # When running in read-only demo mode, if the user is not logged in, treat them as a demo user.
    self.current_user ||= User.find(:email => session[:email])
    if current_user.nil? && (defined?(ENABLE_READONLY_DEMO_MODE) && ENABLE_READONLY_DEMO_MODE)
      self.current_user = User.first(:permission => "demo")
      current_user.rack_session = session
      # Setting this to false silences the exception that Sequel generates when we cancel the default save
      # behavior for demo searches.
      SavedSearch.raise_on_save_failure = false
    else
      SavedSearch.raise_on_save_failure = true
    end
    next if UNAUTHENTICATED_ROUTES.any? { |route| request.path =~ /^#{route}/ }
    next if PERMITTED_USERS.empty? &&
      UNAUTHENTICATED_PREVIEW_ROUTES.any? { |route| request.path =~ /^#{route}/ }
    unless current_user
      # TODO(philc): Revisit this UX. Dumping the user into Google with no explanation is not what we want.

      # Save url to return to it after login completes.
      session[:login_started_url] = request.url
      redirect(OPENID_PROVIDERS_ARRAY.size == 1 ?
         get_openid_login_redirect(OPENID_PROVIDERS_ARRAY.first) :
        "/signin/select_openid_provider")
    end
  end

  get("/favicon.ico") { redirect asset_url("favicon.ico") }

  get("/") { redirect "/commits" }

  get "/signin" do
    session.clear
    session[:login_started_url] = request.referrer
    redirect(OPENID_PROVIDERS_ARRAY.size == 1 ?
       get_openid_login_redirect(OPENID_PROVIDERS_ARRAY.first) :
      "/signin/select_openid_provider")
  end

  get "/signin/select_openid_provider" do
    erb :select_openid_provider, :locals => { :openid_providers => OPENID_PROVIDERS_ARRAY }
  end

  # Users navigate to here from select_openid_provider.
  # - provider_id: an integer indicating which provider from OPENID_PROVIDERS_ARRAY to use for authentication.
  get "/signin/login_using_openid_provider" do
    provider = OPENID_PROVIDERS_ARRAY[params[:provider_id].to_i]
    halt 400, "OpenID provider not found." unless provider
    redirect get_openid_login_redirect(provider)
  end

  # Handle login complete from openid provider.
  get "/signin/complete" do
    @openid_consumer ||= OpenID::Consumer.new(session,
        OpenID::Store::Filesystem.new(File.join(File.dirname(__FILE__), "/tmp/openid")))
    openid_response = @openid_consumer.complete(params, request.url)
    case openid_response.status
    when OpenID::Consumer::FAILURE
      "Sorry, we could not authenticate you with this identifier. #{openid_response.display_identifier}"
    when OpenID::Consumer::SETUP_NEEDED then "Immediate request failed - Setup Needed"
    when OpenID::Consumer::CANCEL then "Login cancelled."
    when OpenID::Consumer::SUCCESS
      ax_resp = OpenID::AX::FetchResponse.from_success_response(openid_response)
      email = ax_resp["http://axschema.org/contact/email"][0]
      unless PERMITTED_USERS.split(",").map(&:strip).include?(email)
        halt 401, "Your email #{email} is not authorized to login to Barkeep."
      end
      session[:email] = email
      unless User.find(:email => email)
        # If there are no admin users yet, make the first user to log in the first admin.
        permission = User.find(:permission => "admin").nil? ? "admin" : "normal"
        User.new(:email => email, :name => email, :permission => permission).save
      end
      redirect session[:login_started_url] || "/"
    end
  end

  get "/signout" do
    session.clear
    redirect request.referrer
  end

  get("/settings") { erb :user_settings }

  put "/settings/:preference" do
    preference = params[:preference]
    if preference == "displayname"
      current_user.name = params[:value]
      current_user.save
    elsif ["line_length", "default_to_side_by_side"].include? preference
      current_user.send :"#{preference}=", params[:value]
      current_user.save
    else
      halt 400, "Bad preference."
    end
    nil
  end

  get "/commits" do
    erb :commit_search, :locals => { :saved_searches => current_user ? current_user.saved_searches : [] }
  end

  # get the one commit that the user is looking for.
  get "/commits/search/by_sha" do
    ensure_required_params :sha
    partial_sha = params[:sha]

    repos = MetaRepo.instance.repos.map(&:name)

    repo_name, sha = repos.each do |repo|
      commit = find_commit(repo, partial_sha, true)
      if commit
        break [repo, commit.sha]
      end
    end

    if sha
      redirect "/commits/#{repo_name}/#{sha}"
    else
      halt 404, "No such sha #{partial_sha}"
    end
  end

  get "/commits/:repo_name/:sha" do
    MetaRepo.instance.scan_for_new_repos
    repo_name = params[:repo_name]
    sha = params[:sha]
    halt 404, "No such repository: #{repo_name}" unless GitRepo[:name => repo_name]
    commit = MetaRepo.instance.db_commit(repo_name, sha)
    unless commit
      begin
        commit = Commit.prefix_match(repo_name, sha)
      rescue RuntimeError => e
        halt 404, e.message
      end
      redirect "/commits/#{repo_name}/#{commit.sha}"
    end
    tagged_diff = GitDiffUtils::get_tagged_commit_diffs(repo_name, commit.grit_commit,
        :use_syntax_highlighting => true)
    erb :commit, :locals => { :tagged_diff => tagged_diff, :commit => commit }
  end

  get "/comment_form" do
    erb :_comment_form, :layout => false, :locals => {
      :repo_name => params[:repo_name],
      :sha => params[:sha],
      :filename => params[:filename],
      :line_number => params[:line_number]
    }
  end

  # I'm using POST even though this is idempotent to avoid massive urls.
  post "/comment_preview" do
    ensure_required_params :text
    commit = MetaRepo.instance.db_commit(params[:repo_name], params[:sha])
    halt 400, "No such commit." unless commit
    Comment.new(:text => params[:text], :commit => commit).filter_text
  end

  post "/comment" do
    if params[:comment_id]
      comment = validate_comment(params[:comment_id])
      comment.text = params[:text]
      comment.save
      next comment.filter_text
    end
    begin
      comment = create_comment(*[:repo_name, :sha, :filename, :line_number, :text].map { |f| params[f] })
    rescue RuntimeError => e
      halt 400, e.message
    end
    erb :_comment, :layout => false, :locals => { :comment => comment }
  end

  post "/delete_comment" do
    comment = validate_comment(params[:comment_id])
    comment.destroy
    nil
  end

  post "/approve_commit" do
    commit = MetaRepo.instance.db_commit(params[:repo_name], params[:commit_sha])
    halt 400 unless commit
    commit.approve(current_user)
    erb :_approved_banner, :layout => false, :locals => { :commit => commit }
  end

  post "/disapprove_commit" do
    commit = MetaRepo.instance.db_commit(params[:repo_name], params[:commit_sha])
    halt 400 unless commit
    commit.disapprove
    nil
  end

  # Saves changes to the user-level search options.
  post "/user_search_options" do
    saved_search_time_period = params[:saved_search_time_period].to_i
    # TODO(philc): We should move this into the model's validations.
    current_user.saved_search_time_period = saved_search_time_period
    current_user.save
    nil
  end

  # POST because this creates a saved search on the server.
  post "/search" do
    MetaRepo.instance.scan_for_new_repos
    options = {}
    [:repos, :authors, :messages].each do |option|
      options[option] = params[option].then { strip.empty? ? nil : strip }
    end
    # Paths is a list
    options[:paths] = params[:paths].to_json if params[:paths] && !params[:paths].empty?
    # Default to only searching master unless branches are explicitly specified.
    options[:branches] = params[:branches].else { "master" }.then { self == "all" ? nil : self }
    saved_search = current_user.new_saved_search(options)
    saved_search.save
    erb :_saved_search, :layout => false, :locals => { :current_user => current_user,
      :saved_search => saved_search, :token => nil, :direction => "before", :page_number => 1 }
  end

  # Gets a page of a saved search.
  # - token: a paging token representing the current page.
  # - direction: the direction of the page to fetch -- either "before" or "after" the given page token.
  # - current_page_number: the current page number the client is showing. This page number is for display
  #   purposes only, because new commits which have been recently ingested will make the page number
  #   inaccurate.
  get "/saved_searches/:id" do
    MetaRepo.instance.scan_for_new_repos
    saved_search = current_user.find_saved_search(params[:id].to_i)
    halt 400, "Bad saved search id." unless saved_search
    token = params[:token] && !params[:token].empty? ? params[:token] : nil
    direction = params[:direction] || "before"
    page_number = params[:current_page_number].to_i + (direction == "before" ? 1 : -1)
    page_number = [page_number, 1].max
    erb :_saved_search, :layout => false, :locals => { :current_user => current_user,
      :saved_search => saved_search, :token => token, :direction => direction, :page_number => page_number }
  end

  # Change the order of saved searches.
  # I'm sure there's a more RESTFUl way to do this call.
  post "/saved_searches/reorder" do
    searches = JSON.parse(request.body.read)
    previous_searches = current_user.saved_searches
    halt 401, "Mismatch in the number of saved searches" unless searches.size == previous_searches.size
    previous_searches.each do |search|
      search.user_order = searches.index(search.id)
      search.save
    end
    nil
  end

  delete "/saved_searches/:id" do
    id = params[:id].to_i
    current_user.delete_saved_search(params[:id].to_i)
    nil
  end

  # Toggles the "unapproved_only" checkbox and renders the first page of the saved search.
  post "/saved_searches/:id/search_options" do
    saved_search = current_user.find_saved_search(params[:id].to_i)
    body_params = JSON.parse(request.body.read)
    [:unapproved_only, :email_commits, :email_comments].each do |setting|
      saved_search.send("#{setting}=", body_params[setting.to_s]) unless body_params[setting.to_s].nil?
    end
    saved_search.save
    nil
  end

  get "/stats" do
    # TODO(dmac): Allow users to change range of stats page without logging in.
    stats_time_range = current_user ? current_user.stats_time_range : "month"
    since = case stats_time_range
            when "hour" then Time.now - 60 * 60
            when "day" then Time.now - 60 * 60 * 24
            when "week" then Time.now - 60 * 60 * 24 * 7
            when "month" then Time.now - 60 * 60 * 24 * 30
            when "year" then Time.now - 60 * 60 * 24 * 30 * 365
            when "all" then Time.at(0)
            else Time.at(0)
            end
    num_commits = Stats.num_commits(since)
    erb :stats, :locals => {
      :num_commits => num_commits,
      :unreviewed_percent => Stats.num_unreviewed_commits(since).to_f / num_commits,
      :commented_percent => Stats.num_reviewed_without_lgtm_commits(since).to_f / num_commits,
      :approved_percent => Stats.num_lgtm_commits(since).to_f / num_commits,
      :chatty_commits => Stats.chatty_commits(since),
      :top_reviewers => Stats.top_reviewers(since),
      :top_approvers => Stats.top_approvers(since)
    }
  end

  post "/set_stats_time_range" do
    halt 400 unless ["hour", "day", "week", "month", "year", "all"].include? params[:since]
    current_user.stats_time_range = params[:since]
    current_user.save
    redirect "/stats"
  end

  get "/profile/:id" do
    user = User[params[:id]]
    halt 404 unless user
    erb :profile, :locals => { :user => user }
  end

  get "/inspire/?" do
    erb :inspire, :locals => { :quote => Inspire.new.quote }
  end

  get %r{/statusz$} do
    statusz_file = File.join(settings.root, "statusz.html")
    File.file?(statusz_file) ? send_file(statusz_file) : "No deploy data."
  end

  post "/request_review" do
    next nil if current_user.demo?
    commit = Commit.first(:sha => params[:sha])
    halt 404 unless commit
    emails = params[:emails].split(",").map(&:strip).reject(&:empty?)
    Resque.enqueue(DeliverReviewRequestEmails, commit.git_repo.name, commit.sha, current_user.email, emails)
    nil
  end

  #
  # Routes for autocompletion.
  #

  get "/autocomplete/authors" do
    users = User.filter("`email` LIKE ?", "%#{params[:substring]}%").
        or("`name` LIKE ?", "%#{params[:substring]}%").distinct(:email).limit(10)
    { :values => users.map { |user| "#{user.name} <#{user.email}>" } }.to_json
  end

  get "/autocomplete/repos" do
    repo_names =  MetaRepo.instance.repos.map {|repo| repo.name}
    { :values => repo_names.select{ |name| name.include?(params[:substring]) } }.to_json
  end

  #
  # Routes used for development purposes.
  #

  # For testing and styling emails.
  # - send_email: set to true to actually send the email for this comment.
  get "/dev/latest_comment_email_preview" do
    comment = Comment.order(:id.desc).first
    next "No comments have been created yet." unless comment
    Emails.send_comment_email(comment.commit, [comment]) if params[:send_email] == "true"
    Emails.comment_email_body(comment.commit, [comment])
  end

  # For testing and styling emails.
  # - send_email: set to true to actually send the email for this commit.
  # - commit: the sha of the commit you want to preview.
  get "/dev/latest_commit_email_preview" do
    commit = params[:commit] ? Commit.first(:sha => params[:commit]) : Commit.order(:id.desc).first
    next "No commits have been created yet." unless commit
    Emails.send_commit_email(commit) if params[:send_email] == "true"
    Emails.commit_email_body(commit)
  end

  private

  def logged_in?() current_user && !current_user.demo? end

  # Construct redirect url to google openid.
  def get_openid_login_redirect(openid_provider_url)
    @openid_consumer ||= OpenID::Consumer.new(session,
        OpenID::Store::Filesystem.new(File.join(File.dirname(__FILE__), "/tmp/openid")))
    begin
      service = OpenID::OpenIDServiceEndpoint.from_op_endpoint_url(openid_provider_url)
      oidreq = @openid_consumer.begin_without_discovery(service, false)
    rescue OpenID::DiscoveryFailure => why
      "Could not contact #{OPENID_DISCOVERY_ENDPOINT}. #{why}"
    else
      ax_request = OpenID::AX::FetchRequest.new
      # Information we require from the OpenID provider.
      required_fields = ["http://axschema.org/contact/email"]
      required_fields.each { |field| ax_request.add(OpenID::AX::AttrInfo.new(field, nil, true)) }
      oidreq.add_extension(ax_request)
      host = "#{request.scheme}://#{request.host_with_port}"
      oidreq.redirect_url(host, "#{host}/signin/complete")
    end
  end

  def create_comment(repo_name, sha, filename, line_number_string, text)
    commit = MetaRepo.instance.db_commit(repo_name, sha)
    raise "No such commit." unless commit
    file = nil
    if filename && !filename.empty?
      file = commit.commit_files_dataset.filter(:filename => filename).first
      file ||= CommitFile.new(:filename => filename, :commit => commit).save
    end
    line_number = (line_number_string && !line_number_string.empty?) ? line_number_string.to_i : nil
    comment = Comment.create(
      :commit => commit,
      :commit_file => file,
      :line_number => line_number,
      :user => current_user,
      :text => text,
      :has_been_emailed => current_user.demo?) # Don't email comments made by demo users.
    comment
  end

  def validate_comment(comment_id)
    comment = Comment[comment_id]
    halt 404, "This comment no longer exists." unless comment
    halt 403, "Comment not originated from this user." unless comment.user.id == current_user.id
    comment
  end
end

# These are extra routes. Require them after the main routes and before filters have been defined, so
# Sinatra's before filters run in the order you would expect.
require "lib/api_routes"
require "lib/admin_routes"

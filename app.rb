#!/usr/bin/env ruby

require "bundler/setup"
require "json"
require "sinatra/base"
require "redcarpet"

require 'openid'
require 'openid/store/filesystem'
require 'openid/extensions/ax'

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")

require "config/environment"
require "lib/script_environment"
require "lib/git_helper"
require "lib/grit_extensions"
require "lib/keyboard_shortcuts"
require "lib/string_helper"
require "lib/pretty_date"
require "lib/stats"

NODE_MODULES_BIN_PATH = "./node_modules/.bin"
OPENID_DISCOVERY_ENDPOINT = "google.com/accounts/o8/id"
OPENID_AX_EMAIL_SCHEMA = "http://axschema.org/contact/email"

class CodeReviewServer < Sinatra::Base
  attr_accessor :current_user

  # Cache for static compiled files (LESS css, coffeescript). In development, we want to only render when the
  # files have changed.
  $compiled_cache = Hash.new { |hash, key| hash[key] = {} }

  set :public, "public"

  configure :development do
    enable :logging
    set :show_exceptions, false
    set :dump_errors, false

    @@repo = Grit::Repo.new(File.dirname(__FILE__))

    error do
      # Show a more developer-friendly error page and stack traces.
      content_type "text/plain"
      error = request.env["sinatra.error"]
      message = error.message + "\n" + cleanup_backtrace(error.backtrace).join("\n")
      puts message
      message
    end
  end

  configure :test do
    set :show_exceptions, false
    set :dump_errors, false
  end

  configure :production do
    enable :logging
  end

  helpers do
    def current_page_if_url(text)
      request.url.include?(text) ? "currentPage" : ""
    end

    def root_url
      request.url.match(/(^.*\/{2}[^\/]*)/)[1]
    end
  end

  before do
    next if request.url =~ /^#{root_url}\/login/
    self.current_user = User.find(:email => request.cookies["email"])
    unless self.current_user
      #save url to return to it after login completes
      response.set_cookie  "login_started_url", :value => request.url, :path => "/"
      redirect get_login_redirect
    end
  end

  get "/" do
    refresh_commits
    redirect "/commits"
  end

  get "/commits" do
    erb :commit_search, :locals => { :saved_searches => current_user.saved_searches, :repo => @@repo }
  end

  get "/commits/:commit_id" do
    repo_commit = @@repo.commit(params[:commit_id])
    tagged_diff = GitHelper::get_tagged_commit_diffs(repo_commit)
    commit = Commit[:sha => params[:commit_id]]
    erb :commit, :locals => { :tagged_diff => tagged_diff, :commit => commit }
  end

  get "/comment_form" do
    erb :_comment_form, :layout => false, :locals => {
      :sha => params[:sha],
      :filename => params[:filename],
      :line_number => params[:line_number]
    }
  end

  post "/comment" do
    commit = Commit.filter({:sha => params[:sha]}).first
    return 400 unless commit
    file = nil
    if params[:filename] && params[:filename] != ""
      file = commit.commit_files_dataset.filter(:filename => params[:filename]).first ||
                CommitFile.new({:filename => params[:filename], :commit => commit}).save
    end
    line_number = params[:line_number] && params[:line_number] != "" ? params[:line_number].to_i : nil
    comment = Comment.new({:commit => commit, :commit_file => file, :line_number => line_number,
                           :user => current_user, :text => params[:text]}).save
    erb :_comment, :layout => false, :locals => { :comment => comment }
  end

  post "/approve_commit" do
    commit = Commit.find(:sha => params[:commit_sha])
    return 400 unless commit
    commit.approved_by_user_id = current_user.id
    commit.save
    erb :_approved_banner, :layout => false, :locals => { :user => current_user }
  end

  post "/disapprove_commit" do
    commit = Commit.find(:sha => params[:commit_sha])
    return 400 unless commit
    commit.approved_by_user_id = nil
    commit.save
  end

  # POST because this creates a saved search on the server.
  post "/search" do
    authors = params[:authors].split(",").map(&:strip).join(",")
    incremented_user_order = (SavedSearch.filter(:user_id => current_user.id).max(:user_order) || -1) + 1
    saved_search = SavedSearch.create(:user_id => current_user.id, :user_order => incremented_user_order)
    # TODO(philc): For now, we're assuming they're always filtering by author.
    SearchFilter.create(:filter_type => SearchFilter::AUTHORS_FILTER, :filter_value => params[:authors],
        :saved_search_id => saved_search.id)
    erb :_saved_search, :layout => false,
      :locals => { :saved_search => saved_search, :repo => @@repo, :page_number => 1 }
  end

  get "/saved_searches/:id" do
    saved_search = SavedSearch[params[:id]]
    page_number = params[:page_number].to_i || 1
    page_number = 1 if page_number <= 0
    erb :_saved_search, :layout => false,
        :locals => { :saved_search => saved_search, :repo => @@repo, :page_number => page_number }
  end

  # Change the order of saved searches.
  # I'm sure there's a more RESTFUl way to do this call.
  post "/saved_searches/reorder" do
    searches = JSON.parse(request.body.read)
    previous_searches = SavedSearch.filter(:user_id => current_user.id).to_a
    halt 401, "Mismatch in the number of saved searches" unless searches.size == previous_searches.size
    previous_searches.each do |search|
      search.user_order = searches.index(search.id)
      search.save
    end
    "OK"
  end

  delete "/saved_searches/:id" do
    id = params[:id].to_i
    SearchFilter.filter(:saved_search_id => id).delete
    SavedSearch.filter(:user_id => current_user.id, :id => id).delete
    "OK"
  end

  post "/saved_searches/:id/email" do
    email_changes = JSON.parse(request.body.read)["email_changes"]
    SavedSearch[:id => params[:id].to_i].update(:email_changes => email_changes)
    "OK"
  end

  #handle login complete from openid provider
  get "/login/complete" do
    @openid_consumer ||= OpenID::Consumer.new(session,
                         OpenID::Store::Filesystem.new("#{File.dirname(__FILE__)}/tmp/openid"))
    openid_response = @openid_consumer.complete(params, request.url)
    case openid_response.status
      when OpenID::Consumer::FAILURE
        "Sorry, we could not authenticate you with this identifier." #{openid_response.display_identifier}"

      when OpenID::Consumer::SETUP_NEEDED
        "Immediate request failed - Setup Needed"

      when OpenID::Consumer::CANCEL
        "Login cancelled."

      when OpenID::Consumer::SUCCESS
        ax_resp = OpenID::AX::FetchResponse.from_success_response(openid_response)
        email = ax_resp["http://axschema.org/contact/email"][0]
        response.set_cookie  "email", :value => email, :path => "/"
        User.new(:email => email, :name => email).save unless User.find :email => email
        redirect request.cookies["login_started_url"] || "/"
    end
  end

  get %r{/keyboard_shortcuts/(.*)$} do
    erb :_keyboard_shortcuts, :layout => false, :locals => { :view => params[:captures].first }
  end

  get "/stats" do
    num_commits = Commit.count
    erb :stats, :locals => {
      :unreviewed_percent => unreviewed_commits.count.to_f / num_commits,
      :commented_percent => reviewed_without_lgtm_commits.count.to_f / num_commits,
      :approved_percent => lgtm_commits.count.to_f / num_commits,
      :chatty_commits => chatty_commits(@@repo, 10),
      :top_reviewers => top_reviewers(10)
    }
  end

  # Serve CSS written in the "Less" DSL by first compiling it. We cache the output of the compilation and only
  # recompile it the source CSS file has changed.
  get "/css/:filename.css" do
    next if params[:filename].include?(".")
    asset_path = "public/#{params[:filename]}.less"
    content_type "text/css", :charset => "utf-8"
    last_modified File.mtime(asset_path)
    compile_asset_from_cache(asset_path) { |filename| `#{NODE_MODULES_BIN_PATH}/lessc #{filename}`.chomp }
  end

  # Render and cache coffeescript when we request the JS of the same name
  get "/js/:filename.js" do
    next if params[:filename].include?(".")
    asset_path = "public/#{params[:filename]}.coffee"
    content_type "application/javascript", :charset => "utf-8"
    last_modified File.mtime(asset_path)
    compile_asset_from_cache(asset_path) { |filename| `#{NODE_MODULES_BIN_PATH}/coffee -cp #{filename}`.chomp }
  end

  get "/profile/:id" do
    user = User[params[:id]]
    halt 404 unless user
    erb :profile, :locals => { :user => user }
  end

  def cleanup_backtrace(backtrace_lines)
    # Don't include the portion of the stacktrace which covers the sinatra intenals. Exclude lines like
    # /opt/local/lib/ruby/gems/1.8/gems/sinatra-1.2.0/lib/sinatra/base.rb:1125:in `call'
    stop_at = backtrace_lines.index { |line| line.include?("sinatra") }
    backtrace_lines[0...stop_at]
  end

  def refresh_commits
    # Hack to get all the commits...this refresh commits is itself a hack that's going away at some point.
    commits = @@repo.commits("master", 9999999)
    commits.each do |commit|
      if DB[:commits].filter(:sha => commit.id).empty?
        DB[:commits].insert(:sha => commit.id, :message => commit.message, :date => commit.date,
            :user_id => get_user(commit.author)[:id])
      end
    end
  end

  def get_user(grit_actor)
    dataset = DB[:users].filter(:email => grit_actor.email)
    if dataset.empty?
      id = DB[:users].insert(:name => grit_actor.name, :email => grit_actor.email)
      DB[:users].filter(:id => id).first
    else
      dataset.first
    end
  end

  private

  # Fetch a file from the cache unless its MD5 has changed. Use a block to specify a transformation to be
  # performed on the asset before caching (e.g. compiling LESS css).
  def compile_asset_from_cache(asset_path, &block)
    # TODO(philc): We should not check the file's md5 more than once when we're running in production mode.
    contents = File.read(asset_path)
    md5 = Digest::MD5.hexdigest(contents)
    cached_asset = $compiled_cache[asset_path]
    if md5 != cached_asset[:md5]
      cached_asset[:contents] = block_given? ? block.yield(asset_path) : File.read(contents)
      cached_asset[:md5] = md5
    end
    cached_asset[:contents]
  end

  # construct redirect url to google openid
  def get_login_redirect
    @openid_consumer ||= OpenID::Consumer.new(session,
        OpenID::Store::Filesystem.new("#{File.dirname(__FILE__)}/tmp/openid"))
    begin
      oidreq = @openid_consumer.begin(OPENID_DISCOVERY_ENDPOINT)
    rescue OpenID::DiscoveryFailure => why
      "Sorry, we couldn't find your identifier #{openid}."
    else
      axreq = OpenID::AX::FetchRequest.new
      axreq.add(OpenID::AX::AttrInfo.new(OPENID_AX_EMAIL_SCHEMA, nil, true))
      oidreq.add_extension(axreq)
      oidreq.redirect_url(root_url,root_url + "/login/complete")
    end
  end
end

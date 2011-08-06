#!/usr/bin/env ruby

require "bundler/setup"
require "json"
require "sinatra/base"

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")

require "lib/script_environment"
require "lib/git_helper"
require "lib/grit_extensions"
require "lib/string_helper"

NODE_MODULES_BIN_PATH = "./node_modules/.bin"

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
  end

  before do
    # Fallback to first user in db for now
    self.current_user = User.find(:email => request.cookies["email"]) || User.first
  end

  get "/" do
    refresh_commits
    erb :index
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

  # Based on the given saved search parameters, generates a reasonable title.
  # TODO(philc): Objectivity saved_searches, and don't assume we're always searching by authors.
  def saved_search_title(search_params)
    "Commits by #{search_params[:authors].join(", ")}"
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

  post "/login" do
    response.set_cookie("email", :value => params[:email], :path => "/") if params[:email]
    redirect "/commits"
  end

  post "/logout" do
    response.delete_cookie("email")
    redirect "/commits"
  end

  get "/profiles/:id" do
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
end

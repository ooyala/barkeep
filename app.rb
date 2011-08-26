#!/usr/bin/env ruby

require "bundler/setup"
require "json"
require "sinatra/base"
require "redcarpet"
require "coffee-script"
require "nokogiri"
require "open-uri"
require "methodchain"

require 'openid'
require 'openid/store/filesystem'
require 'openid/extensions/ax'

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")

require "config/environment"
require "lib/git_helper"
require "lib/keyboard_shortcuts"
require "lib/meta_repo"
require "lib/pretty_date"
require "lib/script_environment"
require "lib/stats"
require "lib/string_helper"
require "lib/inspire"

NODE_MODULES_BIN_PATH = "./node_modules/.bin"
OPENID_DISCOVERY_ENDPOINT = "google.com/accounts/o8/id"
OPENID_AX_EMAIL_SCHEMA = "http://axschema.org/contact/email"

class Barkeep < Sinatra::Base
  attr_accessor :current_user

  #
  # To be called from within the configure blocks, tehse methods must be defined prior to them.
  #
  def self.start_background_email_worker
    command = "ruby " + File.join(File.dirname(__FILE__),  "background_jobs/mail_delivery.rb")
    BackgroundJobs.fork_child_process { exec command }
  end

  def self.start_background_commit_importer
    command = "ruby " + File.join(File.dirname(__FILE__),  "background_jobs/commit_importer.rb")
    BackgroundJobs.fork_child_process { exec command }
  end

  # Cache for static compiled files (LESS css, coffeescript). In development, we want to only render when the
  # files have changed.
  $compiled_cache = Hash.new { |hash, key| hash[key] = {} }
  # Quick logging hack -- Sinatra 1.3 will expose logger inside routes.
  $logger = Logger.new(STDOUT)

  set :public, "public"

  configure :development do
    enable :logging
    set :show_exceptions, false
    set :dump_errors, false

    $logger.level = Logger::DEBUG
    MetaRepo.initialize_meta_repo($logger, REPO_PATHS)

    error do
      # Show a more developer-friendly error page and stack traces.
      content_type "text/plain"
      error = request.env["sinatra.error"]
      message = error.message + "\n" + cleanup_backtrace(error.backtrace).join("\n")
      puts message
      message
    end

    Barkeep.start_background_email_worker
    Barkeep.start_background_commit_importer
  end

  configure :test do
    set :show_exceptions, false
    set :dump_errors, false
  end

  configure :production do
    enable :logging
    $logger.level = Logger::INFO
    MetaRepo.initialize_meta_repo($logger, REPO_PATHS)
    Barkeep.start_background_email_worker
    Barkeep.start_background_commit_importer
  end

  helpers do
    def current_page_if_url(text)
      request.url.include?(text) ? "currentPage" : ""
    end

    def root_url
      request.url.match(/(^.*\/{2}[^\/]*)/)[1]
    end

    def replace_shas_with_links(text)
      text.gsub(/([a-zA-Z0-9]{40})/) { |sha| "<a href='/commits/#{sha}'>#{sha[0..6]}</a>" }
    end
  end

  before do
    self.current_user = User.find(:email => request.cookies["email"])
    next if request.url =~ /^#{root_url}\/login/
    next if request.url =~ /^#{root_url}\/logout/
    next if request.url =~ /^#{root_url}\/commits/
    next if request.url =~ /^#{root_url}\/stats/
    next if request.url =~ /^#{root_url}\/inspire/
    next if request.url =~ /^#{root_url}\/keyboard_shortcuts/
    next if request.url =~ /^#{root_url}\/.*\.css/
    next if request.url =~ /^#{root_url}\/.*\.js/
    next if request.url =~ /^#{root_url}\/.*\.woff/
    unless self.current_user
      #save url to return to it after login completes
      response.set_cookie  "login_started_url", :value => request.url, :path => "/"
      redirect get_login_redirect
    end
  end

  get "/" do
    redirect "/commits"
  end

  get "/login" do
    response.set_cookie  "login_started_url", :value => request.referrer, :path => "/"
    redirect get_login_redirect
  end

  get "/logout" do
    response.delete_cookie  "email"
    redirect request.referrer
  end

  get "/commits" do
    erb :commit_search,
        :locals => { :saved_searches => current_user ? current_user.saved_searches : [] }
  end

  get "/commits/:repo_name/:sha" do
    commit = MetaRepo.db_commit(params[:repo_name], params[:sha])
    tagged_diff = GitHelper::get_tagged_commit_diffs(commit.grit_commit)
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

  post "/comment" do
    commit = MetaRepo.db_commit(params[:repo_name], params[:sha])
    return 400 unless commit
    file = nil
    if params[:filename] && params[:filename] != ""
      file = commit.commit_files_dataset.filter(:filename => params[:filename]).first ||
                CommitFile.new(:filename => params[:filename], :commit => commit).save
    end
    line_number = params[:line_number] && params[:line_number] != "" ? params[:line_number].to_i : nil
    comment = Comment.create(:commit => commit, :commit_file => file, :line_number => line_number,
                             :user => current_user, :text => params[:text])
    Emails.send_comment_email(commit.grit_commit, [comment])
    erb :_comment, :layout => false, :locals => { :comment => comment }
  end

  post "/delete_comment" do
    comment = Comment[params[:comment_id]]
    return 400 unless comment
    return 403 unless comment.user.id == current_user.id
    comment.destroy
    nil
  end

  post "/approve_commit" do
    commit = MetaRepo.db_commit(params[:repo_name], params[:commit_sha])
    return 400 unless commit
    commit.approve(current_user)
    erb :_approved_banner, :layout => false, :locals => { :commit => commit }
  end

  post "/disapprove_commit" do
    commit = MetaRepo.db_commit(params[:repo_name], params[:commit_sha])
    return 400 unless commit
    commit.disapprove
    nil
  end

  # POST because this creates a saved search on the server.
  post "/search" do
    options = {}
    [:repos, :authors, :paths, :messages].each do |option|
      options[option] = params[option] ? params[option].strip : nil
    end
    # Default to only searching master unless branches are explicitly specified.
    options[:branches] = params[:branches].else { "master" }
    incremented_user_order = (SavedSearch.filter(:user_id => current_user.id).max(:user_order) || -1) + 1
    saved_search = SavedSearch.create(
      { :user_id => current_user.id, :user_order => incremented_user_order }.merge options
    )
    erb :_saved_search, :layout => false,
      :locals => { :saved_search => saved_search, :timestamp => nil, :direction => "before" }
  end

  get "/saved_searches/:id" do
    saved_search = SavedSearch[params[:id]]
    timestamp = params[:timestamp].then { to_i }
    direction = params[:direction]
    erb :_saved_search, :layout => false,
        :locals => { :saved_search => saved_search, :timestamp => timestamp, :direction => direction }
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
    # TODO(dmac): Allow users to change range of stats page without loggin in.
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
      :unreviewed_percent => Stats.unreviewed_commits(since).count.to_f / num_commits,
      :commented_percent => Stats.reviewed_without_lgtm_commits(since).count.to_f / num_commits,
      :approved_percent => Stats.lgtm_commits(since).count.to_f / num_commits,
      :chatty_commits => Stats.chatty_commits(since),
      :top_reviewers => Stats.top_reviewers(since)
    }
  end

  post "/set_stats_time_range" do
    halt 400 unless ["hour", "day", "week", "month", "year", "all"].include? params[:since]
    current_user.stats_time_range = params[:since]
    current_user.save
    redirect "/stats"
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
    compile_asset_from_cache(asset_path) { |filename| CoffeeScript.compile(File.read(filename)).chomp }
  end

  get "/profile/:id" do
    user = User[params[:id]]
    halt 404 unless user
    erb :profile, :locals => { :user => user }
  end

  get "/inspire/?" do
    erb :inspire, :locals => { :quote => Inspire.new.quote }
  end

  # A page to help in troubleshooting Barkeep's background processes, like emails and commit ingestion.
  get "/admin/?" do
    erb :admin, :locals => {
      :failed_email_count => EmailTask.filter(:status => "failed").count,
      :recently_failed_emails => EmailTask.filter(:status => "failed").order(:id.desc).limit(15)
    }
  end

  # For development use only -- for testing and styling emails.
  get "/dev/latest_comment_email_preview" do
    comment = Comment.order(:id.desc).first
    Emails.comment_email_body(comment.grit_commit, [comment])
  end


  def cleanup_backtrace(backtrace_lines)
    # Don't include the portion of the stacktrace which covers the sinatra intenals. Exclude lines like
    # /opt/local/lib/ruby/gems/1.8/gems/sinatra-1.2.0/lib/sinatra/base.rb:1125:in `call'
    stop_at = backtrace_lines.index { |line| line.include?("sinatra") }
    backtrace_lines[0...stop_at]
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

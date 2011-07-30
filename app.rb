#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"

require "sinatra/base"

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")

require "lib/script_environment"
require "lib/git_helper"

class CodeReviewServer < Sinatra::Base
  include Grit

  attr_accessor :current_user

  # We compile our css using LESS. When in development, only compile it when it has changed.
  $css_cache = {}

  set :public, "public"

  configure :development do
    enable :logging
    set :show_exceptions, false
    set :dump_errors, false

    @@repo = Repo.new(File.dirname(__FILE__))

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

  before do
    self.current_user = User.first # Pretend a user has been logged in.
  end

  get "/" do
    refresh_commits
    erb :index
  end

  get "/commits" do
    commits = GitHelper.commits_by_authors(@@repo, ["phil"], 8)
    erb :commits, :locals => { :commits => commits }
  end

  post "/saved_searches" do
    authors = params[:authors].split(",").map(&:strip).join(",")
    saved_search = SavedSearch.create(:user_id => current_user.id)
    # TODO(philc): For now, we're assuming they're always filtering by author.
    SearchFilter.create(:filter_type => SearchFilter::AUTHORS_FILTER, :filter_value => params[:authors],
        :saved_search_id => saved_search.id)
    erb :_saved_search, :layout => false,
      :locals => { :commits => saved_search.commits(@@repo), :title => saved_search.title }
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
    # TODO(philc): We should not check the file's md5 more than once when we're running in production mode.
    md5 = Digest::MD5.hexdigest(File.read(asset_path))
    cached_asset = $css_cache[asset_path] ||= {}
    if md5 != cached_asset[:md5]
      cached_asset[:contents] = compile_less_css(asset_path)
      cached_asset[:md5] = md5
    end
    content_type "text/css", :charset => "utf-8"
    last_modified File.mtime(asset_path)
    cached_asset[:contents]
  end

  def compile_less_css(filename) `lessc #{filename}`.chomp end

  def cleanup_backtrace(backtrace_lines)
    # Don't include the portion of the stacktrace which covers the sinatra intenals. Exclude lines like
    # /opt/local/lib/ruby/gems/1.8/gems/sinatra-1.2.0/lib/sinatra/base.rb:1125:in `call'
    stop_at = backtrace_lines.index { |line| line.include?("sinatra") }
    backtrace_lines[0...stop_at]
  end

  def refresh_commits
    commits = @@repo.commits
    commits.each do |commit|
      if DB[:commits].filter(:sha => commit.id).empty?
        commit.author
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
end

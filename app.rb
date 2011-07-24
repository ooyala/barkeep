#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"

require "sinatra/base"
require "sequel"
require "grit"

$LOAD_PATH.push(".")

require "lib/git_helper"

class CodeReviewServer < Sinatra::Base
  include Grit

  # We compile our css using LESS. When in development, only compile it when it has changed.
  $css_cache = {}

  set :public, "public"

  configure :development do
    enable :logging
    set :show_exceptions, false
    set :dump_errors, false

    @@db = Sequel.sqlite("dev.db")
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

  get "/" do
    refresh_commits
    erb :index
  end

  get "/commits" do
    commits = GitHelper.commits_by_authors(@@repo, ["phil"], 8)
    erb :commits, :locals => { :commits => commits }
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
      if @@db[:commits].filter(:sha => commit.id).empty?
        commit.author
        @@db[:commits].insert(:sha => commit.id, :message => commit.message, :date => commit.date,
            :user_id => get_user(commit.author)[:id])
      end
    end
  end

  def get_user(grit_actor)
    dataset = @@db[:users].filter(:email => grit_actor.email)
    if dataset.empty?
      id = @@db[:users].insert(:name => grit_actor.name, :email => grit_actor.email)
      @@db[:users].filter(:id => id).first
    else
      dataset.first
    end
  end
end

  def apply_diff(data, diff)
    data_lines = data.split("\n")
    diff_lines = diff.split("\n")
    tagged_lines = []
    chunk_starts = []
    diff_lines.each_with_index do |line, index|
      match = /^@@ \-(\d+),(\d+) \+\d+,\d+ @@$/.match(line)
      chunk_starts << { :index => index, :line => Integer(match[1]), :length => Integer(match[2]) } if match
    end

    current_line = 1
    chunk_starts.each_with_index do |chunk, index|
      if chunk[:line] > current_line
        tagged_lines += data_lines[current_line-1...chunk[:line]-1].map do |data|
          { :tag => :same, :data => data }
        end
      end
      next_chunk_start = chunk_starts[index+1] || diff_lines.count
      (chunk[:index]+1...next_chunk_start).each do |diff_index|
        case diff_lines[diff_index][0]
        when " " then tag = :same
        when "+" then tag = :added
        when "-" then tag = :removed
        end
        tagged_lines << { :tag => tag, :data => diff_lines[diff_index][1..-1] }
      end
      current_line += chunk[:length]
    end
    last_chunk = chunk_starts[-1]
    remaining_line_number = last_chunk[:line] + last_chunk[:length]
    if remaining_line_number <= data_lines.count
      tagged_lines += data_lines[remaining_line_number..data_lines.count].map do |data|
        { :tag => :same, :data => data }
      end
    end
    tagged_lines
  end
end

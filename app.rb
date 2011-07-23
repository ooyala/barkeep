#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"

require "sinatra/base"

class CodeReviewServer < Sinatra::Base

  configure :development do
    enable :logging
    set :show_exceptions, false
    set :dump_errors, false

    error do
      # Show a more developer-friendly error page and stack traces.
      content_type "text/plain"
      error = request.env["sinatra.error"]
      message = error.message + "\n" + CodeReviewServer.cleanup_backtrace(error.backtrace).join("\n")
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
    "howdy!"
  end

  def self.cleanup_backtrace(backtrace_lines)
    # Don't include the portion of the stacktrace which covers the sinatra intenals. Exclude lines like
    # /opt/local/lib/ruby/gems/1.8/gems/sinatra-1.2.0/lib/sinatra/base.rb:1125:in `call'
    stop_at = backtrace_lines.index { |line| line.include?("sinatra") }
    backtrace_lines[0...stop_at]
  end
end


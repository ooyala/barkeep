source :rubygems

gem "rack"
gem "sinatra", "~> 1.3.2"
gem "rake"

# For managing our Ruby load path.
gem "pathological"

gem "resque"

# For writing CSS more conveniently.
gem "sass", "~> 3.1.16"

# For managing compiling and caching assets
gem "pinion"

# Really nice scss mixin library.
gem "bourbon"

# For JS minification
gem "uglifier"

# We're pulling in our own grit fork with bugfixes.
gem "grit", :git => "http://github.com/ooyala/grit.git", :ref => "38d0e6660b78bff97499280fae09a78b087c50b4"
gem "json"
gem "sequel"
gem "mysql2"
gem "thin"
gem "pygments.rb"
gem "redis"
gem "ruby-openid"
gem "redcarpet", "= 2.0.0b3"
gem "coffee-script"
gem "methodchain"
gem "sinatra-contrib" # For Sinatra::Reloader

# Clockwork is a cron implementation in Ruby. We use it for periodically fetching new commits.
gem "clockwork"

# For running all of our background processes together from a single developer-friendly command.
gem "foreman"

# For sending emails.
gem "pony"

# For rendering erb outside of views.
gem "tilt"

# For generating unified diffs
gem "diff-lcs"

# For validating repo uris
gem "addressable"

# For nicely indented heredocs
gem "dedent"

 # For making exception backtraces more friendly during development.
gem "backtrace_shortener"

# For running our app in production, using multiple workers.
gem "unicorn"

# for templates that can be rendered client and server side
gem "mustache"

# For executing javascript inside Ruby (for compiling coffeescript).
gem "therubyracer"

# For scripting system setup.
gem "terraform"

gem "nokogiri"

group :test do
  # NOTE(caleb): require rr >= 1.0.3 and scope >= 0.2.3 for mutual compatibility
  gem "rr", ">= 1.0.3"
  gem "scope", ">= 0.2.3"
  gem "rack-test"
  gem "pry"
end

group :development do
  gem "fezzik"
  gem "pry"
  gem "awesome_print"
  gem "vagrant", "~> 1.0.5" # For testing deployments
  gem "statusz" # For the deploy information status page
end

source :rubygems

gem "rack"
gem "sinatra"
gem "rerun"
gem "rake"

# For managing our Ruby load path.
gem "pathological"

# Resque is used for managing background jobs.
gem "resque"

# For invoking the Less CSS compiler, written in javascript, from Ruby.
# NOTE(philc): This segfaults sometimes. Replace with sass.
gem "less"

# We're pulling in our own grit fork with bugfixes.
gem "grit", :git => "http://github.com/ooyala/grit.git"
gem "json"
gem "sequel"
gem "mysql"
gem "coffee-script"
gem "thin"
gem "pygments.rb"
gem "redis"
gem "ruby-openid"
gem "redcarpet", "= 2.0.0b3"
gem "coffee-script"
gem "methodchain"

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

group :test do
  # NOTE(caleb): require rr >= 1.0.3 and scope >= 0.2.3 for mutual compatibility
  gem "rr", ">= 1.0.3"
  gem "scope", ">= 0.2.3"
  gem "rack-test"
  gem "nokogiri"
  gem "pry"
end

group :development do
  gem "fezzik"
  gem "pry"
end

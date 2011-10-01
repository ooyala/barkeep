source :rubygems

gem "rack"
gem "sinatra"
gem "rerun"

# Resque is used for managing background jobs.
gem "resque"

# For invoking the Less CSS compiler, written in javascript, from Ruby.
# This would be slightly nicer than using the lessc binary directly, but it
# doesn't seem to be compatible with ruby 1.9.
# gem "less"
gem "json"
gem "grit"
gem "sequel"
gem "mysql"
gem "sqlite3-ruby"
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

# Used for running some of our scripts as daemons.
gem "daemons"

# For sending emails.
gem "pony"

# For rendering erb outside of views.
gem "tilt"

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

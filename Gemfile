source :rubygems

gem "rack"
gem "sinatra"
gem "rerun"

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
gem "albino"
gem "ruby-openid"
gem "redcarpet"
gem "coffee-script"
gem "methodchain"

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

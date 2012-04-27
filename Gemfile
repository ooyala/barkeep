source :rubygems

gem "rack"
gem "sinatra", "~> 1.3.2"
gem "rake"

# For managing our Ruby load path.
gem "pathological"

gem "resque"

# For writing CSS more conveniently.
gem "sass"

# For managing compiling and caching assets
gem "pinion", "~> 0.1.4"

# We're pulling in our own grit fork with bugfixes.
gem "grit", :git => "http://github.com/ooyala/grit.git", :ref => "bf141c49c392781a3a683c06b77d8c3b782e7985"
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
  gem "awesome_print"
  gem "vagrant" # For testing deployments.
  # For scripting system setup. Use the git version for the time being to pull in the latest changes.
  # TODO(caleb): Tie this to a real rubygems release once the Terraform feature set has stabilized a bit.
  gem "terraform"
end

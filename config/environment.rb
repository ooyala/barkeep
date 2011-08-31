#DB_LOCATION = "DBI:Mysql:barkeep:localhost"
DB_LOCATION = "DBI:SQLite:dev.db"
DB_USER = "root"
DB_PASSWORD = ""

# These are the credentials of the Gmail account that you want to send mail as.
# NOTE(philc): We may want to make configuration variables which generically support SMTP.
GMAIL_USERNAME = ""
GMAIL_PASSWORD = ""

# This a list of paths to git repos we should watch.
REPOS_ROOT = "#{ENV["HOME"]}/barkeep_repos"

# This hostname is used to construct links in the commit emails.
BARKEEP_HOSTNAME = "localhost:4567"

REDIS_HOST = "localhost"
REDIS_PORT = 6379


Getting started
===============
pip install pygments
gem install bundler
bundle install
port install nodejs # or brew install node
curl http://npmjs.org/install.sh | sh #install npm
npm install less
run_migrations.sh # db migrations
bin/rerun.sh # run the server
navigate to localhost:4567 # prepopulates the db onload
navigate to localhost:4567/commits # check out the view!


Deployment
==========
Packages needed to install on server before a deploy will work: apt-get the following
mysql-server
mysql-client
libmysqlclient-dev
sqlite3
libsqlite3-dev
openssl
libopenssl-ruby
libssl-dev
python-setuptools

Also install:
pip
pygments

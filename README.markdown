Overview
========
Coming soon!

Setting up Barkeep for development
==================================

This is how it works on our Mac OS dev laptops; YMMV:

    $ easy_install pip
    $ pip install pygments
    $ gem install bundler
    $ bundle install
    $ port install nodejs # or brew install node
      # Note: you may need to "port deactivate c-ares" before installing nodejs
    $ curl http://npmjs.org/install.sh | sh # install npm
    $ npm install less
    $ mysqladmin5 -u root create barkeep  # create the 'barkeep' database
    $ ruby run_migrations.rb # db migrations
    $ redis-server  # run Redis
    $ bin/rerun.sh # run the server

Then you should be able to navigate to navigate to
[http://localhost:4567/commits](http://localhost:4567/commits).

If you're running a Mac using Macports with rvm, ensure your ruby is compiled against the macports openssl
library. Otherwise you will get segfaults when sending emails over SSL:

    $ rvm install 1.9.2 --with-openssl-dir=/opt/local

Running Barkeep Locally
=======================

Make sure you're up to date on Ruby gems (`bundle install`) and on migrations (`ruby run_migrations.rb`).
After that, follow these steps:

    $ redis-server # run Redis
    $ bin/rerun.sh # run the server
    # navigate to localhost:4567/commits

Viewing Repositories
====================

Once Barkeep is set up for development, look in `config/environment.rb`. By default, Barkeep will look in
`~/barkeep_repos/`, though you can change the `REPOS_ROOT` variable to adjust it.

Create the directory and use normal `git clone` to add repositories. Now Barkeep can see them!

You probably shouldn't point Barkeep at your own checkouts, because it will take some time to import lots of
commits and your dev database will be huge. Additionally, although Barkeep should never make any changes
(branch changes or new commits), it *will* fetch a lot in your repositories which may be confusing (you'll be
behind on tracking branches a lot). Instead, clone a few small repositories into the barkeep repos directory.

Deployment
==========

These packages will need to be installed on a linux server before a deploy will work. `apt-get` the following:

    mysql-server
    mysql-client
    libmysqlclient-dev
    sqlite3
    libsqlite3-dev
    openssl
    libopenssl-ruby
    libssl-dev
    python-setuptools
    redis-server

Also install:

    pip
    pygments

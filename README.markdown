Overview
--------
Barkeep is a fast, fun way to review code. Engineering organizations can use it to keep the bar high.

More details coming soon!

Setting up Barkeep for development
----------------------------------

This is how it works on our Mac OS dev laptops; YMMV. First, ensure you've installed
[rbenv](https://github.com/sstephenson/rbenv) and Ruby 1.9.2-p290. (You can get this by installing
[ruby-build](https://github.com/sstephenson/ruby-build) and running `rbenv install 1.9.2-p290`).

    $ easy_install pip
    $ pip install pygments
    $ gem install bundler
    $ bundle install
    $ port install nodejs # or brew install node
      # Note: you may need to "port deactivate c-ares" before installing nodejs if you're using macports
    $ mysqladmin5 -u root create barkeep  # create the 'barkeep' database
    $ ruby run_migrations.rb # db migrations

If you're running a Mac using Macports with rvm, ensure your ruby is compiled against the macports openssl
library. Otherwise you will get segfaults when sending emails over SSL:

    $ rvm install 1.9.2 --with-openssl-dir=/opt/local

Running Barkeep Locally
-----------------------
Make sure you're up to date on Ruby gems (`bundle install`) and on migrations (`ruby run_migrations.rb`).

    $ bin/rerun.sh # run the server
    # navigate to localhost:4567

These are somewhat optional services to run while developing. These background jobs periodically fetch new
commits, pre-generate commit diffs, and send emails when comments are posted.

    $ redis-server # run Redis
    $ rake clockwork:start # start running periodic cron jobs
    $ rake resque:start # start processing any jobs which get added to the Resque queue.

You can view the Resque dashboard and inspect failed Resque jobs by navigating to http://localhost:4567/resque.

Viewing Repositories
--------------------

Once Barkeep is set up for development, look in `config/environment.rb`. By default, Barkeep will look in
`~/barkeep_repos/`, though you can change the `REPOS_ROOT` variable to adjust it.

Create the directory and use normal `git clone` to add repositories. Now Barkeep can see them!

You probably shouldn't point Barkeep at your own checkouts, because it will take some time to import lots of
commits and your dev database will be huge. Additionally, although Barkeep should never make any changes
(branch changes or new commits), it *will* fetch a lot in your repositories which may be confusing (you'll be
behind on tracking branches a lot). Instead, clone a few small repositories into the barkeep repos directory.

Deployment
----------

We're deploying to Ubuntu Lucid (10.04 LTS). This is the required setup before we can deploy Barkeep.

1.  Install required packages:

        $ sudo apt-get install curl mysql-server mysql-client libmysqlclient-dev sqlite3 libsqlite3-dev \
        openssl libopenssl-ruby libssl-dev python-setuptools redis-server python-software-properties

2.  You'll need a recent (1.7.6+) version of git. On Ubuntu, the git-core package may be out-of-date -- you
    can install a very recent version from the git-core ppa:

        $ sudo add-apt-repository ppa:git-core/ppa
        $ sudo apt-get update
        $ sudo apt-get install git-core

3.  Install the required Python packages:

        $ sudo easy_install pip
        $ sudo pip install pygments

4.  Install [rbenv](https://github.com/sstephenson/rbenv):

        $ git clone git://github.com/sstephenson/rbenv.git .rbenv
        # Put the following lines at the top of ~/.bashrc:
          export PATH="$HOME/.rbenv/bin:$PATH"
          eval "$(rbenv init -)"
        # Ensure that ~/.bash_profile sources ~/.bashrc:
          source "$HOME/.bashrc"
        $ exec $SHELL

5.  Install [ruby-build](https://github.com/sstephenson/ruby-build) and get Ruby 1.9.2-p290:

        $ git clone git://github.com/sstephenson/ruby-build.git
        $ cd ruby-build
        $ sudo ./install.sh
        $ rbenv install 1.9.2-p290

6. Install [node.js](http://nodejs.org/):

        $ wget http://nodejs.org/dist/node-v0.4.12.tar.gz
        $ tar xzvf node-v0.4.12.tar.gz && cd node-v0.4.12/
        $ ./configure && make
        $ sudo make install

You should now be able to deploy to the server. The deployment tasks will install the required gems and take
care of any remaining setup tasks.

Setting up email
----------------
Set the email address and password of the Gmail account you want to use with Barkeep in `config/environment.rb`.

Note that emails for new commits are sent from user**+commits**@example.com and comments are sent from
user**+comments**@example.com. By default, Gmail won't allow your account to send from these addresses
[without explicitly allowing them](https://mail.google.com/support/bin/answer.py?answer=22370). Enabling this
is easy -- log in to the Gmail account you're going to use with Barkeep and add these two addresses in
[Settings > Accounts and Import > Send Mail As](http://mail.google.com/mail/#settings/accounts).

Authors
-------

Barkeep was written by the following Ooyala engineers:

* Bo Chen ([bo-chen](https://github.com/bo-chen))
* Phil Crosby ([philc](https://github.com/philc))
* Kevin Le ([bkad](https://github.com/bkad))
* Daniel MacDougall ([dmacdougall](https://github.com/dmacdougall))
* Caleb Spare ([cespare](https://github.com/cespare))

and with contributions from:

* [Noah Gibbs](mailto:noah@ooyala.com)
* Brian Zhou ([zdyn](https://github.com/zdyn))

License
-------

Barkeep is released under [the MIT license](http://www.opensource.org/licenses/mit-license.php).

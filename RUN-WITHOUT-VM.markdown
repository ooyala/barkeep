Running Barkeep standalone
==========================

While most barkeep development happens in a Vagrant VM, you can also run barkeep normally, without a VM.


Installation
------------

Install `rbenv` and make sure you have the version specified in `.rbenv` installed and set up.

Install redis.

Install a MySQL server, set up a user/database with all permissions (they are usually called `barkeep`/`barkeep`).

Run `bundle install` to install barkeep's dependencies.

Edit `environment.rb` and set variables like `db_user` according to your DB setup.

Run `script/run_migrations.rb` to initialize the database.

If you wish to have the demo user, run `script/create_demo_user.rb`.


Startup
-------

Run these programs at the same time:

```bash
# Start webserver

bin/run_app.bash

# Start daemons:
# - resque: background jobs system
# - clockwork: cron-like daemon responsible for fetching commits

script/run_resque.rb
script/run_clockwork.rb
```

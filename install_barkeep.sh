#!/bin/bash

# This script is tested for a clean Ubuntu 10.04 image. It's a starting point for a fresh Barkeep install,
# but the important dependencies are:
# - mysql
# - redis
# - git 1.7.6+
# - ruby 1.9.3-p194
# As long as these dependencies are met, you can proceed to the "Clone Barkeep" step.
# If you don't want to set up a reverse proxy you can skip installing and configuring nginx.

# Install core dependencies
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y g++ build-essential libxslt1-dev libxml2-dev \
  python-dev libmysqlclient-dev redis-server mysql-server nginx

# Install git 1.7.6+
sudo apt-get -y install python-software-properties
sudo add-apt-repository -y ppa:git-core/ppa && sudo apt-get update
sudo apt-get install -y git

# Install ruby 1.9.3-p194
git clone git://github.com/sstephenson/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile
echo 'eval "$(rbenv init -)"' >> ~/.profile
source ~/.profile
git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install 1.9.3-p194
rbenv global 1.9.3-p194
gem install bundler
rbenv rehash

# Clone Barkeep
git clone git://github.com/ooyala/barkeep.git ~/barkeep
cd ~/barkeep && bundle install && rbenv rehash

# Configure a reverse proxy webserver (nginx) to Barkeep
sudo rm /etc/nginx/sites-enabled/default
sudo cp ~/barkeep/config/system_setup_files/nginx_site.prod.conf /etc/nginx/sites-enabled/barkeep
sudo /etc/init.d/nginx restart

# Create database and run migrations
mysqladmin -u root --password='' create barkeep
cd ~/barkeep && ./script/run_migrations.rb

# Create upstart scripts
cd ~/barkeep
foreman export upstart upstart_scripts -a barkeep -l /var/log/barkeep -u $USER -f Procfile
sudo mv upstart_scripts/* /etc/init

# Configure and start barkeep
cp environment.prod.rb environment.rb
cp environment.prod.sh environment.sh
echo "******************************"
echo "To configure sending emails from Barkeep, edit GMAIL_ADDRESS and GMAIL_PASSWORD\
 in environment.rb and run: sudo restart barkeep"
echo "******************************"
sudo start barkeep

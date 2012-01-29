#!/bin/sh
# This file will be called to start your application.


nohup bundle exec script/run_clockwork.rb > /dev/null 2>&1 &
nohup bundle exec rake resque:work QUEUE=* > /dev/null 2>&1 &
RACK_ENV=production nohup bundle exec thin start -p 8081 -R config.ru > /dev/null 2>&1 &


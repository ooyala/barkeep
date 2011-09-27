#!/bin/sh
# This file will be called to start your application.

RACK_ENV=production nohup bundle exec thin start -p 8081 -R config.ru > /dev/null 2>&1 &


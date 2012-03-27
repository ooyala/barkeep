#!/bin/sh
# This file will be called to start the web process.
# TODO(caleb): Stop using thin, delete this file and use unicorn instead (and run multiple workers)

RACK_ENV=production bundle exec thin start -p 8081 -R config.ru

#!/bin/bash
bundle exec unicorn -c config/unicorn.barkeep.conf 2> >(grep --line-buffered -v "bust")
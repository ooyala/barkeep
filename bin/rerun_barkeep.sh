#!/bin/bash
bundle exec rerun --pattern '{config.ru,lib/**.rb,config/*,*.rb}' -- \
thin start -p 4567 -R config.ru \
2> >(grep --line-buffered -v "cache_bust")

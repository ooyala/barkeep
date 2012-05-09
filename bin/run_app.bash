#!/bin/bash

# environment.sh is present after a production deploy, and contains env vars like UNICORN_WORKERS.
if [ -f environment.sh ]; then
  source environment.sh
fi

# Filter livecss's requests (with cache_bust=<randomnumber>)
bundle exec unicorn -c config/unicorn.barkeep.conf 2> >(grep --line-buffered -v "cache_bust=")

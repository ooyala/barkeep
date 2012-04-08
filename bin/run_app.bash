#!/bin/bash
bundle exec rackup --port ${BARKEEP_PORT:-4567} config.ru 2> >(grep --line-buffered -v "bust")
        
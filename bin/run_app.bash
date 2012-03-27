#!/bin/bash
bundle exec rackup --port ${PORT:-4567} config.ru 2> >(grep --line-buffered -v "bust")

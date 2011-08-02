#!/bin/sh
rerun --pattern '{deploy/*,**/*.{rb,js,ru,coffee}}' -- rackup --port 4567 config.ru

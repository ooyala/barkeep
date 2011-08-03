#!/bin/sh
rerun --pattern '{deploy/*,**/*.{rb,js,ru,coffee,erb}}' -- rackup --port 4567 config.ru

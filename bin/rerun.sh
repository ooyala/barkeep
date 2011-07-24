#!/bin/sh
rerun --pattern '{deploy/*,**/*.{rb,js,css,ru}}' -- rackup --port 4567 config.ru

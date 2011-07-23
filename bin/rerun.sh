#!/bin/sh
rerun --pattern '{deploy/*,**/*.{rb,js,css,erb,ru}}' -- rackup --port 4567 config.ru

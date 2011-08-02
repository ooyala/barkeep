#!/bin/sh
rerun --pattern '{deploy/*,**/*.{rb,js,css,ru,coffee,less}}' -- rackup --port 4567 config.ru

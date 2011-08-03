#!/bin/sh
rerun --pattern '{deploy/*,**/*.{rb,ru}}' -- thin start -p 4567 -R config.ru

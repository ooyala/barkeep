#!/bin/bash
bundle exec rerun --pattern '{deploy/*,**/*.{rb,ru,txt}}' -- thin start -p 4567 -R config.ru

#!/bin/bash
rerun --pattern '{deploy/*,**/*.{rb,ru}}' -- thin start -p 4567 -R config.ru 2> >(grep -v "cache_bust")

#!/usr/bin/env bash

echo "Latest commit:"
git log --pretty=%H -n 1
echo
echo "Current branch:"
git branch --no-color | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
echo
echo "Date:"
date -u
echo
echo "Current user on host:"
whoami
echo
echo "Git user info:"
git config --get user.name
git config --get user.email

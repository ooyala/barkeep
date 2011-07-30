#
# Loads up our models environment for use by scripts.

require "rubygems"
require "bundler/setup"
require "grit"

$LOAD_PATH.push(".") unless $LOAD_PATH.include?(".")
require "lib/models"

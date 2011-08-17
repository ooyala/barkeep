#!/usr/bin/env ruby

require "./config/environment.rb"

PROTOCOL, DB_TYPE, DB_NAME, DB_HOST = DB_LOCATION.split(":")

case DB_TYPE
when "Mysql"
  `sequel -m migrations/ "mysql://#{DB_USER}@#{DB_HOST}/#{DB_NAME}"`
when "SQLite"
  `sequel -m migrations/ "sqlite://#{DB_NAME}"`
end

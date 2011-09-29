require "./app"
require "resque/server"
run Rack::URLMap.new(
    "/"       => Barkeep.new,
    "/resque" => Resque::Server.new)
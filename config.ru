require "./barkeep_server"
require "resque/server"

map("/resque") { run Resque::Server.new }
map(BarkeepServer.pinion.mount_point) { run BarkeepServer.pinion }
map("/") { run BarkeepServer }

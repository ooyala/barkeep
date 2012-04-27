require "./app"
require "resque/server"
require "pinion"

PINION_MOUNT_POINT = "/assets"
pinion = Pinion::Server.new(PINION_MOUNT_POINT)
pinion.convert :scss => :css
pinion.convert :coffee => :js
pinion.watch "public"

map(PINION_MOUNT_POINT) { run pinion }
map("/resque") { run Resque::Server.new }
map("/") { run Barkeep.new(pinion) }

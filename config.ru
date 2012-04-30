require "./app"
require "resque/server"
require "pinion"

# NOTE(caleb): We need to require bourbon somewhere so that it is available when the sass is compiled (inside
# Pinion -- see the watch for the bourbon styles directory below). If we do not require bourbon, there will be
# annoying bugs because the sass extension function 'compact', defined in Ruby, will be unavailable, and the
# generated css will contain invalid things like "compact(#fff, #000, false, false, false...)"
require "bourbon"

PINION_MOUNT_POINT = "/assets"
pinion = Pinion::Server.new(PINION_MOUNT_POINT)
pinion.convert :scss => :css
pinion.convert :coffee => :js
pinion.watch "public"
pinion.watch "#{Gem.loaded_specs["bourbon"].full_gem_path}/app/assets/stylesheets"

map(PINION_MOUNT_POINT) { run pinion }
map("/resque") { run Resque::Server.new }
map("/") { run Barkeep.new(pinion) }

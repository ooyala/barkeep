module BarkeepClient
  SHA_REGEX = /[0-9a-fA-F]+/
  CONFIG_FILE = File.join(ENV["HOME"], ".barkeeprc")
  REQUIRED_CONFIG_KEYS = %w[barkeep_server]
end

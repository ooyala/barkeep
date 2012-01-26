require "barkeep/configuration"
require "barkeep/version"

module BarkeepClient
  COMMANDS = {
    "commit" => "Get information about a particular commit.",
    "unapproved" => "Find unapproved commits from a list or commit range.",
    "view" => "View a barkeep commit page in your browser."
  }

  COMMANDS.keys.each { |command| require "barkeep/#{command}" }
end

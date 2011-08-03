# Extensions that are monkey-patched into Grit for convenience.

require "grit"

module Grit
  class Commit
    def link
      "/commit/#{@id}"
    end
  end
end

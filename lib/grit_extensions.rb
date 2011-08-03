# Extensions that are monkey-patched into Grit for convenience.

require "grit"

module Grit
  class Commit
    def link
      "/commits/#{@id}"
    end
  end
end

# Extensions that are monkey-patched into Grit for convenience.

require "grit"

module Grit
  class Commit
    def link
      "/commits/#{@id}"
    end
  end

  class Actor
    def user
      @user ||= User.find(:email => self.email)
    end
  end
end

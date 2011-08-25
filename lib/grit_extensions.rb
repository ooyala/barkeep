# Extensions that are monkey-patched into Grit for convenience.

require "grit"

module Grit
  class Commit
    def repo_name=(name)
      @repo_name = name
    end

    def link
      "/commits/#{@repo_name}/#{@id}"
    end
  end

  class Actor
    def user
      @user ||= User.find(:email => self.email)
    end
  end
end

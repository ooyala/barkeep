# Extensions that are monkey-patched into Grit for convenience.

require "grit"

module Grit
  class Commit
    attr_accessor :repo_name

    def link
      "/commits/#{@repo_name}/#{@id}"
    end

    def timestamp
      date.to_i
    end
  end

  class Repo
    attr_accessor :name
  end

  class Actor
    def user
      @user ||= User.find(:email => self.email)
    end
  end
end

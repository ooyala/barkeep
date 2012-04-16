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
    def origin_url() self.config.fetch("remote.origin.url") end

    # False if the repo is in such a state where it has no commits yet. This can happen if there was an error
    # cloning, or if it's a freshly initialized empty repo.
    def is_valid?
      return false unless (self.head rescue false)
      self.commits(self.head.name, 0, 1).empty?
    end
  end

  class Actor
    def user
      @user ||= User.find(:email => self.email)
    end

    # The default to_s() for Actor only includes the author's name, not email.
    def display_string
      # If the author's display name is empty, which it sometimes is, strip() will eliminate the whitespace.
      "#{self.to_s} <#{self.email}>".strip
    end

    def gravatar
      hash = Digest::MD5.hexdigest(self.email.downcase)
      image_src = "http://www.gravatar.com/avatar/#{hash}"
    end
  end
end

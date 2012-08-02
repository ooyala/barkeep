# Extensions that are monkey-patched into Grit for convenience.

# NOTE(caleb): Several methods (Commit#message, Actor#name, Actor#email) are monkey-patched to force UTF-8
# encoding. This is because grit will return ASCII-8BIT strings (essentially a binary byte sequence) for these
# fields, and this causes problems because Ruby 1.9 won't let you concatenate these with UTF-8 strings unless
# the ASCII-8BIT string has no byte values > 128.

require "grit"
require "methodchain"

module Grit
  class Commit
    attr_accessor :repo_name
    def link() "/commits/#{@repo_name}/#{@id}" end
    def timestamp() date.to_i end

    unless self.method_defined? :message_original
      alias_method :message_original, :message
      def message() message_original.then { force_encoding("utf-8") } end
    end
  end

  class Repo
    attr_accessor :name
    def origin_url() self.config.fetch("remote.origin.url") end
    def has_refs?() !self.refs.empty? end
  end

  class Actor
    unless self.method_defined? :name_original
      alias_method :name_original, :name
      def name() name_original.then { force_encoding("utf-8") } end
    end
    unless self.method_defined? :email_original
      alias_method :email_original, :email
      def email() email_original.then { force_encoding("utf-8") } end
    end

    def user() @user ||= User.find(:email => email) end

    # The default to_s() for Actor only includes the author's name, not email.
    def display_string
      # If the author's display name is empty, which it sometimes is, strip() will eliminate the whitespace.
      "#{name} <#{email}>".strip
    end

    def gravatar
      hash = Digest::MD5.hexdigest(email.downcase)
      image_src = "//gravatar.com/avatar/#{hash}"
    end
  end
end

# A logged-in user can comment and have their view preferences saved.
#
# Fields:
#  - email
#  - username

require "digest/md5"

class User < Sequel::Model
  one_to_many :saved_searches, :order => [:user_order.desc]
  one_to_many :comments

  def gravatar
    hash = Digest::MD5.hexdigest(email.downcase)
    image_src = "http://www.gravatar.com/avatar/#{hash}"
  end

  def demo?() permission == "demo" end
  def admin?() permission == "admin" end

  def session_saved_searches(saved_searches_options)
    return [] if saved_searches_options.nil?
    saved_searches_options.map { |options| SavedSearch.new(options) }
  end
end

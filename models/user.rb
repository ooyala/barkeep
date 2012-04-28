# A logged-in user can comment and have their view preferences saved.
#
# Fields:
#  - email
#  - username

require "lib/api"
require "digest/md5"

class User < Sequel::Model
  one_to_many :saved_searches, :order => [:user_order.desc]
  one_to_many :comments

  # Assign the user an api key and secret on creation
  def before_create
    self.api_key = Api.generate_user_key
    self.api_secret = Api.generate_user_key
    super
  end

  def gravatar
    hash = Digest::MD5.hexdigest(email.downcase)
    image_src = "http://www.gravatar.com/avatar/#{hash}"
  end

  def demo?() permission == "demo" end
  def admin?() permission == "admin" end
end

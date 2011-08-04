# A logged-in user can comment and have their view preferences saved.
#
# Fields:
#  - email
#  - username

require "digest/md5"

class User < Sequel::Model
  one_to_many :saved_searches, :order => [:user_order.desc]

  def gravatar
    hash = Digest::MD5.hexdigest(email.downcase)
    image_src = "http://www.gravatar.com/avatar/#{hash}"
  end
end

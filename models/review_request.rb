class ReviewRequest < Sequel::Model
  many_to_one :commit
  many_to_one :requester_user, :class => User
  many_to_one :reviewer_user, :class => User
end

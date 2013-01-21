# This class encapsulates the data for an entry in a "review list" on the "Reviews" page.

class ReviewListEntry
  attr_accessor :grit_commit
  attr_accessor :review_request

  def initialize(grit_commit)
    @grit_commit = grit_commit
    @review_request = nil
  end
end

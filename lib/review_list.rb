# This class encapsulates the data for a "review list" on the "Reviews" page.

class ReviewList
  attr_accessor :entries
  attr_accessor :token

  DEFAULT_LIST = "uncompleted_reviews,actionable_comments,recent_reviews,requests_from_me," +
      "pending_comments,closed_comments"

  def initialize(entries, token)
    @entries = entries
    @token = token
  end

  def page_number
    @token.split(";", 2)[0].to_i
  end

  # A token contains the following values, separated by a semi-colon:
  #   page_number ; from_values ; to_values ; is_partial
  # where
  #   page_number   is the page number of the current page
  #   is_partial    is "true" if the list is only partially filled
  #   from_values   is either the first commit id in the list, or a comma-separated pair
  #                 of values (commit_id, date)
  #   to_values     is either the last commit id in the list, or a comma-separated pair
  #                 of values (commit_id, date)
  def self.parse_token(token)
    page_number, from_values, to_values, is_partial = token.split(";")
    from_values = from_values.split(",")
    from_values[0] = from_values[0].to_i
    to_values = to_values.split(",")
    to_values[0] = to_values[0].to_i
    [page_number.to_i, from_values, to_values, (is_partial == "true")]
  end

  def self.make_token(page_number, from_values, to_values, is_partial)
    from_values = Array(from_values)
    to_values = Array(to_values)
    "#{page_number};#{from_values.join(',')};#{to_values.join(',')};#{is_partial}"
  end
end

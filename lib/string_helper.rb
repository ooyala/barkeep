# Some utilities for generating strings appearing in Barkeep.

module StringHelper
  DAY_SECONDS = 60 * 60 * 24

  def self.result_size(count)
    case count
    when 0
      "No results."
    when 1
      "1 result."
    else
      "#{count} results."
    end
  end

  # TODO(caleb): Give a more intelligent date format (e.g. "12:35pm today" or "about 3 minutes ago", etc).
  def self.smart_date(time)
    elapsed_time = Time.now - time
    return "The future!!!" if elapsed_time < 0
    time.strftime "%b %d, %Y"
  end
end

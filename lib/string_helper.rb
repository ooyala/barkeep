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

  # A terse date represenation in the form of "Aug 21, 2011". Used by views where relative dates don't work
  # well, like in our email views.
  def self.short_date(time)
    time.strftime "%b %d, %Y"
  end

  def self.pluralize(count, singular, plural = nil)
    text = (count == 1) ? singular : (plural || "#{singular}s")
    "#{count} #{text}"
  end
end

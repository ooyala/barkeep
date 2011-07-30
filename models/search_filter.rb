# Each saved search has one or more search filters.
#
# Fields:
#  - filter_type: the type of the filter. Valid values are "authors", "directories".
#  - filter_value: the value of the filter, e.g. "dmac" if searching for commits by dmac.

class SearchFilter < Sequel::Model
  many_to_one :saved_searches
end
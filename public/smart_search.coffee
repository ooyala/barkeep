# A smart search box that helps the user find search parameters

class window.SmartSearch
  constructor: (@searchBox) ->

  parseSearch: (searchString) ->
    parts = (part for part in searchString.split(" ") when part != "")
    query = { paths: [] }
    for part in parts
      [key, value] = part.split(":", 2)
      if value?
        if key == "paths" then query.paths.push(value) else query[key] = value
      else
        # For now, assume any value with no : is a path.
        query.paths.push part
    query

  search: ->
    queryParams = @parseSearch(@searchBox.val())
    $.post("/search", queryParams, (e) => CommitSearch.onSearchSaved e)

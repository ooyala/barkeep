# A smart search box that helps the user find search parameters

class window.SmartSearch
  constructor: ->
    @searchBox = $("#commitSearch input[name=filter_value]")

  focus: ->
    @searchBox.focus()
    @searchBox.select()
    # TODO(caleb): We can tab-complete keywords ("repo", "author", ...) and even talk to the server to
    # autocomplete values for some fields if we want to get fancy. Start listening to user input and parse it
    # to do that.

  unfocus: ->
    # TODO(caleb) Unhook listeners set up in focus()
    @searchBox.blur()

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
    @unfocus()

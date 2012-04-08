# A smart search box that helps the user find search parameters

class window.SmartSearch
  constructor: (@searchBox) ->

  # Allow for some synonym keywords
  SYNONYMS =
    author: "authors"
    branch: "branches"
    repo: "repos"

  # fetches autocomplete suggestions and returns it through the callback with an array of labels and values
  #   eg. [ { label: "Choice1", value: "value1" }, ... ]
  # see jqueryUI autocomplete for more infomation
  autocomplete: (searchString, callback) ->
    knownKeys = ["repos:", "authors:", "paths:", "branches:"]

    partialQuery = @parsePartialQuery(searchString)
    if (partialQuery.partialValue == "")
      if (partialQuery.key != "")
        possibleKeys = (key for key in knownKeys when key.indexOf(partialQuery.key) > -1)
        callback(possibleKeys) unless possibleKeys.length == 0
    else if (partialQuery.key in ["authors", "repos"])
      $.ajax
        type: "get"
        url: "/autocomplete/#{partialQuery.key}"
        data: { substring: partialQuery.partialValue }
        dataType: "json"
        success: (completion) ->
          authorResultsRegex = /(<.*>)/
          fullValues = $.map completion.values, (x) ->
            authorsMatches = authorResultsRegex.exec(x)
            result = {
              label : x,
              value : partialQuery.unrelatedPrefix + partialQuery.key + ":" + authorsMatches[1]
            }
          callback(fullValues)
        error: -> callback ""



  # Parse a partial search string so we can help complete the search query for the user.
  #
  # Returns: an object with the properties
  #  - key: set to the last key the user had typed
  #  - partialValue: to the last value being typed
  #  - unrelatedPrefix: to unrelated complete clauses that were
  #
  # It is possible for both key and partialValue to be empty or for partialValue: to be empty.
  parsePartialQuery: (searchString) ->
    currentKey = ""
    currentValue = ""
    previousClauseLength = 0
    state = "Key" # two possible states: "Key" or "Value"

    stateMachine = (i, char) ->
      if (state == "Key")
        if (char == ":" and currentKey != "")
          state = "Value"
        else if (char != ' ')
          currentKey += char
        else if (char == ' ')
          currentKey = ""
      else if state ==  "Value"
        if (char == ",")
          currentValue = ""
          previousClauseLength = i+1
        else if (char == " ")
          state = "Key"
          currentKey = ""
          currentValue = ""
        else
          currentValue += char

    # remove spaces around separators ':' and ','
    searchString = searchString.replace(/\s+:|:\s+/g, ":").replace(/\s+,|,\s+/g, ",")

    $.each searchString.split(""), stateMachine
    key = if SYNONYMS[currentKey]? then SYNONYMS[currentKey] else currentKey
    { key: key, partialValue: currentValue, unrelatedPrefix: searchString.split(0,previousClauseLength) }

  parseSearch: (searchString) ->
    # This could be repo, author, etc. If it is nil when we're done processing a key/value pair, then assume
    # the value is a path.
    currentKey = null
    # Current value -- likely just a single string, but perhaps a longer array of strings to be joined with
    # commas.
    currentValue = []
    query = { paths: [] }

    # String trim (could move this to a utility class if it is useful elsewhere).
    trim = (s) -> s.replace(/^\s+|\s+$/g, "")

    emitKeyValue = (key, value) ->

      looksLikeSha = (chunk) ->
        # sha is 40 chars but is usually shortened to 7. Ensure that we don't pick up words by mistake
        # by checking that there is atleast one digit in the chunk.
        return chunk.match(/[0-9a-f]{7,40}/) and chunk.match(/\d/g).length > 0

      if key in ["paths"]
        if (looksLikeSha(value))
          query["sha"] = value
         else
          query.paths.push(value)
      else
        query[key] = value

    # Handle one space-delimited chunk from the search query. We figure out from the previous context how to
    # handle it.
    emitChunk = (chunk) ->
      chunk = trim(chunk)
      return if chunk == ""
      # If we've seen a key, we're just appending (possibly comma-separated) parts.
      if currentKey?
        notLast = chunk[chunk.length - 1] == ","
        currentValue.push(part) for part in chunk.split(",") when part != ""
        return if notLast
        emitKeyValue(currentKey, currentValue.join(","))
        currentKey = null
        currentValue = []
      # Else we're expecting a new chunk (i.e. a search key followed by a colon).
      else
        splitPoint = chunk.indexOf(":")
        switch splitPoint
          when -1 then emitKeyValue("paths", chunk) # Assume it's a path if it's not a key (i.e. no colon).
          when 0 then emitChunk(chunk.slice(1))
          else
            currentKey = chunk.slice(0, splitPoint)
            emitChunk(chunk.slice(splitPoint + 1))

    emitChunk(chunk) for chunk in searchString.split(/\s+/)

    # Take care of un-emmitted key/value pair (this happens when you have a trailing comma).
    if currentKey?
      emitKeyValue(currentKey, currentValue.join(","))

    for synonym, keyword of SYNONYMS
      if query[synonym]?
        query[keyword] ?= query[synonym]
        delete query[synonym]

    query

  search: ->
    queryParams = @parseSearch(@searchBox.val())
    if (queryParams.sha)
      # we are expecting a single commit, just redirect to a new page.
      window.open("/commits/search/by_sha?" + $.param(queryParams))
    else
      $.post("/search", queryParams, (e) => CommitSearch.onSearchSaved e)

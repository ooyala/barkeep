# A smart search box that helps the user find search parameters

class window.SmartSearch
  constructor: (@searchBox) ->

  # Allow for some synonym keywords
  SYNONYMS =
    author: "authors"
    branch: "branches"
    repo: "repos"

  KEYS = ["repos:", "authors:", "paths:", "branches:"]

  # fetches autocomplete suggestions and returns it through the callback with an array of labels and values
  #   eg. [ { label: "Choice1", value: "value1" }, ... ]
  # see jqueryUI autocomplete for more infomation
  autocomplete: (searchString, callback) ->
    # trim multiple spaces and remove spaces around separators ':' and ','
    searchString = searchString.replace(/\s+/g," ").replace(/\s+:|:\s+/g, ":").replace(/\s+,|,\s+/g, ",")

    # slice to focus on the last term
    unrelatedPrefix = ""
    currentTerm = ""
    lastTermSeparator = searchString.lastIndexOf(" ")
    if lastTermSeparator >= 0
      unrelatedPrefix = searchString.slice(0, lastTermSeparator+1)
      currentTerm = searchString.slice(lastTermSeparator+1)
    else
      currentTerm = searchString

    # separate into key and value
    lastKeyValueSeparator = currentTerm.lastIndexOf(":")
    if lastKeyValueSeparator >= 0
      # key is done, autocomplete value
      key = currentTerm.slice(0, lastKeyValueSeparator+1)
      unrelatedPrefix += key
      @autocompleteValue(currentTerm.slice(lastKeyValueSeparator+1), key, unrelatedPrefix, callback)
    else
      @autocompleteKey(currentTerm, unrelatedPrefix, callback)

  # suggests keys see autocomplete
  autocompleteKey: (incompleteKey, unrelatedPrefix, callback) ->
    if incompleteKey == ""
      callback(KEYS)
    else
      results = []
      for key in KEYS
        results.push {"label": key, "value": unrelatedPrefix + key} if key.indexOf(incompleteKey) > -1
      callback(results)

  # suggests values see autocomplete
  autocompleteValue: (incompleteValues, key, unrelatedPrefix, callback) ->
    previousValues = ""
    currentValue = ""
    lastValueSeparator = incompleteValues.lastIndexOf(",")

    # focus only on latest value
    if lastValueSeparator >= 0
      unrelatedPrefix += incompleteValues.slice(0,lastValueSeparator+1)
      currentValue = incompleteValues.slice(lastValueSeparator+1)
    else
      currentValue = incompleteValues

    if key in ["authors:", "repos:"]
      $.ajax
        type: "get"
        url: "/autocomplete/#{key[0..key.length-2]}"
        data: { substring: currentValue }
        dataType: "json"
        success: (completion) ->
          authorResultsRegex = /(<.*>)/
          fullValues = $.map completion.values, (x) ->
            authorsMatches = authorResultsRegex.exec(x)
            result = {
              label : x,
              value : unrelatedPrefix + authorsMatches[1]
            }
          callback(fullValues)
        error: -> callback ""

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

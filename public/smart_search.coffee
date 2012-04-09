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
    parseResult = @parsePartialQuery(searchString)
    if parseResult.searchType == "key"
      @autocompleteKey(parseResult.key, parseResult.unrelatedPrefix, callback)
    else
      @autocompleteValue(parseResult.value, parseResult.key, parseResult.unrelatedPrefix, callback)

  # Parse a partial search string so we can help complete the search query for the user.
  #
  # Returns: an object with the properties
  #  - key: set to the last key the user had typed
  #  - partialValue: to the last value being typed
  #  - unrelatedPrefix: to unrelated terms that need to be prefixed on to the suggested value or key
  #  - searchType: "key" or "value"
  #
  parsePartialQuery: (searchString) ->
    # trim multiple spaces and remove spaces around separators ':' and ','
    searchString = searchString.replace(/\s+/g," ").replace(/\s+:|:\s+/g, ":").replace(/\s+,|,\s+/g, ",")
    result = { key: "", value: "",  unrelatedPrefix: "", searchType: "" }

    # slice to focus on the last term
    currentTerm = ""
    lastTermSeparator = searchString.lastIndexOf(" ")
    if lastTermSeparator >= 0
      result.unrelatedPrefix = searchString.slice(0, lastTermSeparator+1)
      currentTerm = searchString.slice(lastTermSeparator+1)
    else
      currentTerm = searchString

    # separate into key and value
    lastKeyValueSeparator = currentTerm.lastIndexOf(":")
    if lastKeyValueSeparator < 0
      result.key = currentTerm
      result.searchType = "key"
      return result

    # if key is done, autocomplete value
    result.searchType = "value"
    result.key = currentTerm.slice(0, lastKeyValueSeparator+1)
    result.unrelatedPrefix += result.key
    values = currentTerm.slice(lastKeyValueSeparator+1)

    # separate multiple values
    lastValueSeparator = values.lastIndexOf(",")
    if lastValueSeparator >= 0
      result.unrelatedPrefix += values.slice(0,lastValueSeparator+1)
      result.value = values.slice(lastValueSeparator+1)
    else
      result.value = values
    result

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
  autocompleteValue: (incompleteValue, key, unrelatedPrefix, callback) ->
    if key in ["authors:", "repos:"]
      # regex to get value out of full label
      valueRegex = /^.*$/
      valueRegex = /<.*>/ if key == "authors:"

      $.ajax
        type: "get"
        url: "/autocomplete/#{key[0..key.length-2]}"
        data: { substring: incompleteValue }
        dataType: "json"
        success: (completion) ->
          fullValues = $.map completion.values, (x) ->
            {"label" : x, "value" : unrelatedPrefix + (valueRegex.exec(x)[0] || "")}
          callback(fullValues)
        error: -> callback ""
    else callback ""

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

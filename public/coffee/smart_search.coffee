# A smart search box that helps the user find search parameters

class window.SmartSearch
  constructor: (@searchBox) ->

  # Allow for some synonym keywords
  SYNONYMS =
    author: "authors"
    branch: "branches"
    repo: "repos"

  KEYS = ["repos:", "authors:", "paths:", "branches:"]

  # fetches autocomplete suggestions and returns it through the onSuggestionReceived callback with an array of
  # labels and values
  #   eg. [ { label: "Choice1", value: "value1" }, ... ]
  # see jqueryUI autocomplete for more infomation
  autocomplete: (searchString, onSuggestionReceived) ->
    @searchString = searchString
    parseResult = @parsePartialQuery(@searchString)
    if parseResult.searchType == "key"
      @autocompleteKey(parseResult.key, parseResult.unrelatedPrefix, onSuggestionReceived)
    else
      @autocompleteValue(parseResult.value, parseResult.key, parseResult.unrelatedPrefix, onSuggestionReceived)

  # Parse a partial search string so we can help complete the search query for the user.
  #
  # Returns: an object with the properties
  #  - key: set to the last key the user had typed that may need to be completed/suggestions
  #  - partialValue: to the last value being typed that needs to be completed/suggestions
  #  - unrelatedPrefix: unrelated previous words in the text box where autosuggestion is not being performed
  #     on but needs to be added back to the front of suggested values
  #  - searchType: whether complete should be performed on "key" or "value"
  #
  #  Example, parsePartialQuery("repos:db, barkeep,coffee").returns
  #    key: "repos:",
  #    value: "coffee",
  #    unrelatedPrefix: "repos:db,barkeep,",
  #    searchType: "value"
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

  # suggests keys. See autocomplete.
  autocompleteKey: (incompleteKey, unrelatedPrefix, onSuggestionReceived) ->
    nokey = (incompleteKey == "")
    results = []
    for key in KEYS
      if nokey || key.indexOf(incompleteKey) > -1
        results.push { "label": key, "value": unrelatedPrefix + key }
    @showTabCompleteHint(incompleteKey, results)
    onSuggestionReceived(results)

  # suggests values. See autocomplete.
  autocompleteValue: (incompleteValue, key, unrelatedPrefix, onSuggestionReceived) ->
    if key in ["authors:", "repos:", "branches:"]
      # regex to get value out of full label
      valueRegex = /^.*$/
      valueRegex = /<.*>/ if key == "authors:"

      repos = ""
      if key == "branches:" && (@searchString.indexOf("repos:") >= 0)
        repos = /repos:\s*(\S+)\b/.exec(@searchString)[1]

      $.ajax
        type: "get"
        url: "/autocomplete/#{key[0..key.length-2]}"
        data: { substring: incompleteValue, repos: repos }
        dataType: "json"
        success: (completion) =>
          fullValues = $.map completion.values, (x) ->
            {"label" : x, "value" : unrelatedPrefix + (valueRegex.exec(x)[0] || "")}
          @showTabCompleteHint(incompleteValue, fullValues)
          onSuggestionReceived(fullValues)
        error: -> onSuggestionReceived ""
    else onSuggestionReceived ""

  showTabCompleteHint: (incompleteTerm, suggestions) ->
    hint = value = ""
    if incompleteTerm
      # Get the first autocomplete suggestion that starts with the search term (case insensitive). If one
      # doesn't exist, don't offer a hint.
      re = new RegExp("^" + Util.escapeRegex(incompleteTerm), "i")
      $.each suggestions, (i, suggestion) ->
        if re.test(suggestion.label)
          hint = suggestion.label
          value = suggestion.value
          false
      # Copy the entire current search to the hint box and append the hint to the end.
      hint = @searchString + hint.slice(incompleteTerm.length) if hint
    # Store the actual tab complete value because the label in the suggestion box and the value that actually
    # gets inserted can be different
    @searchBox.data("tabComplete", value).siblings(".tabCompleteHint").val(hint)

  hideTabCompleteHint: ->
    @searchBox.removeData("tabComplete").siblings(".tabCompleteHint").val("")

  tabComplete: ->
    value = @searchBox.data("tabComplete")
    # Tab complete only if a hint exists.
    if value
      @searchBox.val(value)
      # Trigger the next round of autocomplete suggestions if value is a key (e.g. "repos:", "authors:")
      @searchBox.autocomplete(if value[value.length - 1] == ":" then "search" else "close")

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

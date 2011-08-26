# import common.coffee, jquery, jquery UI, and jquery-json

window.CommitSearch =
  init: ->
    $("#commitSearch .submit").click (e) => @onSearchClick e
    $("#commitSearch input[name=filter_value]").keydown (e) => @onKeydownInSearchbox e
    $("#commitSearch input[name=filter_value]").keypress (e) => KeyboardShortcuts.beforeKeydown(e)
    $(document).keydown (e) => @onKeydown e
    $("#savedSearches").sortable
      placeholder: "savedSearchPlaceholder"
      handle: ".dragHandle"
      axis: "y"
      stop: => @reorderSearches()
    $("#savedSearches .savedSearch .delete").live "click", (e) => @onSavedSearchDelete e
    $("#savedSearches .savedSearch .pageLeftButton").live "click", (e) => @showNextPage(e, "after")
    $("#savedSearches .savedSearch .pageRightButton").live "click", (e) => @showNextPage(e, "before")
    $("#savedSearches .savedSearch .emailCheckbox").live "click", (e) => @emailUpdate(e)
    @selectFirstDiff()

  onSearchClick: ->
    $("#commitSearch input[name=filter_value]").blur()
    searchString = $("#commitSearch input[name=filter_value]").val()
    # TODO(caleb): option parsing -- for now, assume they're searching authors
    queryParams = { authors: searchString }
    $.post("/search", queryParams, (e) => @onSearchSaved e)

  onSearchSaved: (responseHtml) ->
    $("#savedSearches").prepend responseHtml
    @selectFirstDiff()

  onSavedSearchDelete: (event) ->
    target = $(event.target).parents(".savedSearch")
    searchId = (Number) target.attr("saved-search-id")
    if $(".selected").parents(".savedSearch").is(target)
      @selectNewGroup(false) unless @selectNewGroup(true)
      removedSelected = true
    target.remove()
    ScrollWithContext(".selected") if removedSelected
    @deleteSearch(searchId)
    false

  onKeydownInSearchbox: (event) ->
    return unless KeyboardShortcuts.beforeKeydown(event)
    switch KeyboardShortcuts.keyCombo(event)
      when "return"
        @onSearchClick()
      when "escape"
        $("#commitSearch input[name=filter_value]").blur()
        ScrollWithContext(".selected")

  onKeydown: (event) ->
    return unless KeyboardShortcuts.beforeKeydown(event)
    switch KeyboardShortcuts.keyCombo(event)
      when "/"
        window.scroll(0, 0)
        $("#commitSearch input[name=filter_value]").focus()
        $("#commitSearch input[name=filter_value]").select()
        return false
      when "j"
        @selectDiff(true)
      when "k"
        @selectDiff(false)
      when "h"
        @showNextPage(event, "after")
      when "l"
        @showNextPage(event, "before")
      when "return"
        window.location.href = $("#savedSearches .commitsList tr.selected .commitLink").attr("href")
      else
        KeyboardShortcuts.globalOnKeydown(event)

  # Swap the current selection for a new one
  selectNewDiff: (next) ->
    $(".selected").removeClass "selected"
    next.addClass "selected"

  # If next = false then move to the previous group instead
  selectNewGroup: (next = true) ->
    selected = $(".selected")
    newlySelected = $()
    group = selected.parents(".savedSearch")
    while newlySelected.size() == 0
      group = if next then group.next() else group.prev()
      return false if group.size() == 0
      newlySelected = if next then group.find("tr:first-of-type") else group.find("tr:last-of-type")
    @selectNewDiff(newlySelected)
    ScrollWithContext(".selected")
    true

  selectFirstDiff: ->
    selectedGroup = $("#savedSearches .savedSearch:first-of-type")
    while selectedGroup.size() > 0
      selected = selectedGroup.find(".commitsList tr:first-of-type")
      if selected.size() > 0
        @selectNewDiff(selected)
        ScrollWithContext(".selected")
        break
      selectedGroup = selectedGroup.next()

  # If true then next; else previous
  # Returns true on success
  selectDiff: (next = true) ->
    selected = $(".selected")
    newlySelected = if next then selected.next() else selected.prev()
    if newlySelected.size() > 0
      @selectNewDiff(newlySelected)
      ScrollWithContext(".selected")
      return true
    @selectNewGroup(next)

  # Shows the next page of a commit search.
  # direction: "before" or "after"
  showNextPage: (event, direction = "before") ->
    return if @searching

    if event.type == "keydown"
      savedSearch = $(".selected").parents(".savedSearch")
      keypress = true
    else # event.type == "click"
      savedSearch = $(event.target).parents(".savedSearch")
      keypress = false

    savedSearchId = savedSearch.attr("saved-search-id")
    savedSearchElement = $(".savedSearch[saved-search-id=#{savedSearchId}]")

    buttons = savedSearchElement.find(".pageControls")
    button = buttons.find(if direction == "before" then ".pageRightButton" else ".pageLeftButton")

    @searching = true

    # If it's a keypress, highlight the button for a moment as if the user clicked on it.
    if keypress
      button.addClass("active")
      timeout 70, => button.removeClass("active")

    token = savedSearch.attr(if direction == "before" then "from-token" else "to-token")

    animationComplete = false
    fetchedHtml = null

    # We're going to animate sliding the current page away, while at the same time fetching the new page.
    # When both of those events are done, showFetchedPage can then be called.
    showFetchedPage = =>
      return unless animationComplete and fetchedHtml
      @searching = false
      newSavedSearchElement = $(fetchedHtml)

      if newSavedSearchElement.find(".commitsList tr").size() == 0
        # Circumstances on the server must've changed recently -- it believes we have no more commits.
        # Just fade-in the previous page as if it was the next page.
        savedSearchElement.find(".commitsList").css({ "margin-left": 0, "opacity": 0 })
        newSavedSearchElement = savedSearchElement
      else
        newSavedSearchElement.css("height": savedSearchElement.height())
        newSavedSearchElement.find(".commitsList").css("opacity", 0)
        savedSearchElement.replaceWith newSavedSearchElement
        $(".selected").removeClass "selected"
        newSavedSearchElement.find(".commitsList tr:first").addClass "selected"

      newSavedSearchElement.find(".commitsList").animate({ "opacity": 1 }, { duration: 150 })

    animateTo = (if direction == "before" then -1 else 1) * $(".commitsList").width()
    savedSearchElement.find(".commitsList").animate { "margin-left": animateTo },
      duration: 400,
      complete: =>
        animationComplete = true
        showFetchedPage()

    $.ajax
      url: "/saved_searches/#{savedSearchId}?token=#{token}&direction=#{direction}",
      success: (html) =>
        fetchedHtml = html
        showFetchedPage()

  reorderSearches: ->
    @beforeSync()
    state = for savedSearch in $("#savedSearches .savedSearch")
      (Number) $(savedSearch).attr("saved-search-id")
    # Store from the bottom up so that adding new saved searches doesn't change all the numbers.
    state.reverse()
    window.state = state
    $.ajax
      type: "POST"
      contentTypeType: "application/json"
      url: "/saved_searches/reorder"
      data: $.toJSON(state)
      success: => @afterSync()

  deleteSearch: (id) ->
    @beforeSync()
    $.ajax
      type: "DELETE"
      url: "/saved_searches/#{id}"
      success: => @afterSync()

  emailUpdate: (event) ->
    @beforeSync()
    data = { email_changes: $(event.target).attr("checked") == "checked" }
    id = (Number) $(event.target).parents(".savedSearch").attr("saved-search-id")
    $.ajax
      type: "POST"
      contentTypeType: "application/json"
      url: "/saved_searches/#{id}/email"
      data: $.toJSON(data)
      success: => @afterSync()

  beforeSync: ->
    # The right thing to do here is to queue up this state and re-sync when the current sync callback happens.
    if @synching
      alert "Another sync in progress...server connection problems?"
      return
    @synching = true

  afterSync: ->
    @synching = false

$(document).ready(-> CommitSearch.init())

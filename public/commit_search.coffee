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
    $("#savedSearches .savedSearch .pageLeftButton").addClass "disabled"
    $("#savedSearches .savedSearch .pageLeftButton").live "click", (e) => @showNextPage(e, "backward")
    $("#savedSearches .savedSearch .pageRightButton").live "click", (e) => @showNextPage(e, "forward")
    $("#savedSearches .savedSearch .emailCheckbox").live "click", (e) => @emailUpdate(e)
    @selectFirstDiff()

  onSearchClick: ->
    $("#commitSearch input[name=filter_value]").blur()
    authors = $("#commitSearch input[name=filter_value]").val()
    return unless authors
    queryParams = { authors: authors }
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
    @scrollWithContext() if removedSelected
    @deleteSearch(searchId)
    false

  onKeydownInSearchbox: (event) ->
    return unless KeyboardShortcuts.beforeKeydown(event)
    switch KeyboardShortcuts.keyCombo(event)
      when "return"
        @onSearchClick()
      when "escape"
        $("#commitSearch input[name=filter_value]").blur()
        @scrollWithContext()

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
        @showNextPage(event, "backward")
      when "l"
        @showNextPage(event, "forward")
      when "return"
        window.location.href = $("#savedSearches .commitsList tr.selected .commitLink").attr("href")
      else
        KeyboardShortcuts.globalOnKeydown(event)

  # Swap the current selection for a new one
  selectNewDiff: (next) ->
    $(".selected").removeClass "selected"
    next.addClass "selected"

  # Keep some amount of context on-screen to pad the selection position
  scrollWithContext: ->
    selection = $(".selected")
    return unless selection.size() > 0
    selectionTop = selection.offset().top
    selectionBottom = selectionTop + selection.height()
    windowTop = $(window).scrollTop()
    windowBottom = windowTop + $(window).height()
    # If the selection if off-screen, center on it
    if selectionBottom < windowTop or selectionTop > windowBottom
      window.scroll(0, (selectionTop + selectionBottom) / 2 - $(window).height() / 2)
    # Otherwise ensure there is enough buffer
    else if selectionTop - windowTop < Constants.CONTEXT_BUFFER_PIXELS
      window.scroll(0, selectionTop - Constants.CONTEXT_BUFFER_PIXELS)
    else if windowBottom - selectionBottom < Constants.CONTEXT_BUFFER_PIXELS
      window.scroll(0, selectionBottom + Constants.CONTEXT_BUFFER_PIXELS - $(window).height())

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
    @scrollWithContext()
    true

  selectFirstDiff: ->
    selectedGroup = $("#savedSearches .savedSearch:first-of-type")
    while selectedGroup.size() > 0
      selected = selectedGroup.find(".commitsList tr:first-of-type")
      if selected.size() > 0
        @selectNewDiff(selected)
        @scrollWithContext()
        break
      selectedGroup = selectedGroup.next()

  # If true then next; else previous
  # Returns true on success
  selectDiff: (next = true) ->
    selected = $(".selected")
    newlySelected = if next then selected.next() else selected.prev()
    if newlySelected.size() > 0
      @selectNewDiff(newlySelected)
      @scrollWithContext()
      return true
    @selectNewGroup(next)

  # Shows the next page of a commit search.
  # direction: "forward" or "backward".
  showNextPage: (event, direction = "forward") ->
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
    button = buttons.find(if direction == "forward" then ".pageRightButton" else ".pageLeftButton")
    return if button.hasClass "disabled"

    @searching = true

    # If it's a keypress, highlight the button for a moment as if the user clicked on it.
    if keypress
      button.addClass("active")
      timeout 70, =>
        button.removeClass("active")

    pageNumber = (Number) savedSearch.attr("page-number")
    pageNumber = if direction == "forward" then pageNumber + 1 else pageNumber - 1

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

        buttons = newSavedSearchElement.find(".pageControls")
        if pageNumber <= 1
          buttons.find(".pageLeftButton").addClass "disabled"

      newSavedSearchElement.find(".commitsList").animate({ "opacity": 1 }, { duration: 150 })
      # TODO(caleb): Implement counting result size on the server and sending that back to the client, so
      # that we can know how many pages of results there are and when to stop paging properly.

    animateTo = (if direction == "forward" then -1 else 1) * $(".commitsList").width()
    savedSearchElement.find(".commitsList").animate({ "margin-left": animateTo },
        {
          duration: 400,
          complete: =>
            animationComplete = true
            showFetchedPage()
        })

    $.ajax
      url: "/saved_searches/#{savedSearchId}?page_number=#{pageNumber}",
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

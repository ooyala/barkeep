window.CommitSearch =
  REFRESH_PERIOD_MINUTES: 2

  init: ->
    @smartSearch = new SmartSearch $("#commitSearch input[name=filter_value]")
    @autocompleteOpen = false

    # Register shortcuts
    shortcuts =
      "j": => @selectDiff true
      "k": => @selectDiff false
      "h": (e) => @showNextPage "after"
      "l": (e) => @showNextPage "before"
      "r": (e) => @refreshAllSearches()
    KeyboardShortcuts.registerPageShortcut(shortcut, action) for shortcut, action of shortcuts
    for shortcut in ["return", "o"]
      KeyboardShortcuts.registerPageShortcut shortcut, (e) =>
        window.open $("#savedSearches .commitsList tr.selected .commitLink").attr("href")
    searchBox = $("#commitSearch input[name=filter_value]")
    KeyboardShortcuts.createShortcutContext searchBox
    KeyboardShortcuts.registerPageShortcut "/", (e) =>
      window.scroll 0, 0
      $("#commitSearch input[name=filter_value]").focus()
      $("#commitSearch input[name=filter_value]").select()
      # We need to return false because this event is fired before we have focus on the input element (any
      # events fired once we have focus will be handled appropriately by jquery.hotkeys.
      false
    KeyboardShortcuts.registerShortcut searchBox, "return", (e) =>
      @smartSearch.search()
      $("#commitSearch input[name=filter_value]").blur()
    KeyboardShortcuts.registerShortcut searchBox, "tab", (e) =>
      # Tab complete only if a suggestion isn't highlighted. jQuery gives the highlighted suggestion this id.
      if !$('#ui-active-menuitem')[0]
        @smartSearch.tabComplete()
        return false
      false if @autocompleteOpen
    KeyboardShortcuts.registerShortcut searchBox, "esc", (e) =>
      $("#commitSearch input[name=filter_value]").blur()
      Util.scrollWithContext(".selected")

    $("#commitSearch .submit").click (e) => @smartSearch.search()
    $("#commitSearch select[name='time_range']").change (e) => @timeRangeChanged(e)
    $("#commitSearch input[name=filter_value]").autocomplete
      source: (request, callback) => @smartSearch.autocomplete(request.term, callback),
      open: (event, ui) => @autocompleteOpen = true
      close: (event, ui) =>
        @autocompleteOpen = false
        @smartSearch.hideTabCompleteHint()
      focus: (event, ui) => @smartSearch.hideTabCompleteHint()

    $("#savedSearches").sortable
      placeholder: "savedSearchPlaceholder"
      handle: ".dragHandle"
      axis: "y"
      start: =>
        $.fn.tipsy.disable()
      stop: =>
        $.fn.tipsy.enable()
        @reorderSearches()
    $("#savedSearches .savedSearch .delete").live "click", (e) => @onSavedSearchDelete e
    $("#savedSearches .savedSearch .pageLeftButton").live "click", (e) => @showNextPage "after", e
    $("#savedSearches .savedSearch .pageRightButton").live "click", (e) => @showNextPage "before", e

    # We save separate event handlers for these checkboxes, even though they're related, because
    # toggling show_unapproved_commits requires a full search refresh while the others do not.
    $(".searchOptions input[name='show_unapproved_commits']").live "change",
        (e) => @toggleUnapprovedCommits(e)
    $(".searchOptions input[name='email_commits']").live "change", (e) => @changeEmailOptions(e)
    $(".searchOptions input[name='email_comments']").live "change", (e) => @changeEmailOptions(e)
    $(".searchOptionsLink").live "click", (e) => @onSearchOptionsClicked(e)
    # Refresh the searches periodically so that the the user can leave the page open and see new results.
    Util.setInterval @REFRESH_PERIOD_MINUTES * 60 * 1000, => @automaticallyRefreshSearches()
    @selectFirstDiff()

  onSearchSaved: (responseHtml) ->
    $("#savedSearches").prepend responseHtml
    @selectFirstDiff()

  timeRangeChanged: (event) ->
    new_time_period = $(event.target).val()
    $.ajax
      url: "/user_search_options?saved_search_time_period=#{new_time_period}",
      type: "POST",
      success: =>
        @refreshAllSearches()

  onSavedSearchDelete: (event) ->
    target = $(event.target).parents(".savedSearch")
    searchId = parseInt(target.attr("saved-search-id"))
    if $(".selected").parents(".savedSearch").is(target)
      @selectNewGroup(false) unless @selectNewGroup(true)
      removedSelected = true
    target.remove()
    Util.scrollWithContext(".selected") if removedSelected
    @deleteSearch(searchId)
    false

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
    Util.scrollWithContext(".selected")
    true

  selectFirstDiff: ->
    selectedGroup = $("#savedSearches .savedSearch:first-of-type")
    while selectedGroup.size() > 0
      selected = selectedGroup.find(".commitsList tr:first-of-type")
      if selected.size() > 0
        @selectNewDiff(selected)
        Util.scrollWithContext(".selected")
        break
      selectedGroup = selectedGroup.next()

  # If true then next; else previous
  # Returns true on success
  selectDiff: (next = true) ->
    selected = $(".selected")
    newlySelected = if next then selected.next() else selected.prev()
    if newlySelected.size() > 0
      @selectNewDiff(newlySelected)
      Util.scrollWithContext(".selected")
      return true
    @selectNewGroup(next)

  # Shows the next page of a commit search.
  # direction: "before" or "after"
  showNextPage: (direction = "before", event = null) ->
    return if @searching

    if event? # Triggered by click
      event.preventDefault()
      savedSearch = $(event.target).parents(".savedSearch")
      keypress = false
    else # Triggered by hotkey
      savedSearch = $(".selected").parents(".savedSearch")
      keypress = true

    savedSearchId = savedSearch.attr("saved-search-id")
    savedSearchElement = $(".savedSearch[saved-search-id=#{savedSearchId}]")

    buttons = savedSearchElement.find(".pageControls")
    button = buttons.find(if direction == "before" then ".pageRightButton" else ".pageLeftButton")

    @searching = true

    # If it's a keypress, highlight the button for a moment as if the user clicked on it.
    if keypress
      button.addClass("active")
      Util.setTimeout 70, => button.removeClass("active")

    token = savedSearch.attr(if direction == "before" then "from-token" else "to-token")
    currentPageNumber = parseInt(savedSearchElement.find(".pageNumber").text())
    if isNaN(currentPageNumber)
      # Something is wrong
      @selectFirstDiff()
      @searching = false
      return

    # If we're on page 1 and trying to go "after", then do a refresh instead of the normal sliding paging.
    if currentPageNumber == 1 && direction == "after"
      if @refreshing
        @searching = false
        return
      @refreshing = true
      @refreshSearch(savedSearchElement, "fade", => @refreshing = false)
      @searching = false
      return

    animationComplete = false
    fetchedHtml = null
    $(".tipsy").remove()

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
      url: "/saved_searches/#{savedSearchId}",
      data: { token: token, direction: direction, current_page_number: currentPageNumber },
      success: (html) =>
        fetchedHtml = html
        showFetchedPage()

  reorderSearches: ->
    @beforeSync()
    state = for savedSearch in $("#savedSearches .savedSearch")
      parseInt($(savedSearch).attr("saved-search-id"))
    # Store from the bottom up so that adding new saved searches doesn't change all the numbers.
    state.reverse()
    $.ajax
      type: "POST"
      contentType: "application/json"
      url: "/saved_searches/reorder"
      data: $.toJSON(state)
      success: => @afterSync()

  deleteSearch: (id) ->
    @beforeSync()
    $.ajax
      type: "DELETE"
      url: "/saved_searches/#{id}"
      success: => @afterSync()

  onSearchOptionsClicked: (event) ->
    event.preventDefault()
    searchOptionsMenu = $(event.target).parent().find(".searchOptionsMenu")
    @showSearchOptionsMenu searchOptionsMenu, !(searchOptionsMenu.attr("animatingDirection") == "in")

  showSearchOptionsMenu: (searchOptionsMenu, shouldShow) ->
    searchOptionsMenu.stop(true, true) # Stop any currently-running animations.

    # We perform a bouncing animation as the menu slides in.
    dropShadowHeight = 6
    startingPosition = searchOptionsMenu.outerHeight() + dropShadowHeight
    bouncePadding = 18

    firstTimeShown = searchOptionsMenu.css("display") == "none"
    if firstTimeShown
      searchOptionsMenu.css("top", -startingPosition)
      searchOptionsMenu.show()

    if shouldShow
      searchOptionsMenu.attr("animatingDirection", "in")
      searchOptionsMenu.animate({ top: -bouncePadding }, 210, "easeOutBack")

      # We listen for clicks outside of this menu, so we can dismiss this menu.
      dismissMenu = (event) =>
        isClickWithinMenu = $(event.target).parents().filter(searchOptionsMenu).size() > 0
        return if isClickWithinMenu
        $(document).unbind("click", dismissMenu)
        if searchOptionsMenu.attr("animatingDirection") == "in"
          @showSearchOptionsMenu(searchOptionsMenu, false)

      $(document).click(dismissMenu)
    else
      searchOptionsMenu.attr("animatingDirection", "out")
      searchOptionsMenu.animate({ top: -startingPosition }, 210, null)

  toggleUnapprovedCommits: (event) ->
    savedSearch = $(event.target).parents(".savedSearch")
    savedSearchId = parseInt(savedSearch.attr("saved-search-id"))
    requestBody = { unapproved_only: $(event.target).attr("checked") == "checked" }
    @beforeSync()
    $.ajax
      type: "POST"
      contentType: "application/json"
      url: "/saved_searches/#{savedSearchId}/search_options"
      data: jQuery.toJSON(requestBody)
      success: =>
        @afterSync()
        @refreshing = true
        @refreshSearch(savedSearch, "fade", => @refreshing = false)

  changeEmailOptions: (event) ->
    savedSearch = $(event.target).parents(".savedSearch")
    savedSearchId = parseInt(savedSearch.attr("saved-search-id"))
    form = $($(event.target).parents(".searchOptionsMenu"))
    requestBody = {
      email_commits: form.find("input[name=email_commits]").attr("checked") == "checked",
      email_comments: form.find("input[name=email_comments]").attr("checked") == "checked",
    }

    $.ajax
      type: "POST"
      contentType: "application/json"
      url: "/saved_searches/#{savedSearchId}/search_options"
      data: jQuery.toJSON(requestBody)

  # Refresh a saved search with the latest from the server.
  #  - savedSearch: a JQuery savedSearch div
  #  - animation: the type of animation to use ("fade" or "none").
  #  - callback: an optional callback called after the refresh is finished.
  refreshSearch: (savedSearch, animation = "fade", callback = ->) ->
    savedSearchId = parseInt(savedSearch.attr("saved-search-id"))
    selected = $(".selected").parents(".savedSearch").is(savedSearch)
    fetchNewSavedSearch = (context, after) =>
      @beforeSync()
      $.ajax
        url: "/saved_searches/#{savedSearchId}"
        success: (newSavedSearchHtml) =>
          @afterSync()
          context.newSavedSearch = $(newSavedSearchHtml)
          after()
    replaceSavedSearch = (context) =>
      savedSearchElement = $(".savedSearch[saved-search-id=#{savedSearchId}]")
      savedSearchElement.replaceWith context.newSavedSearch
      context.newSavedSearch.find(".commitsList tr:first").addClass "selected" if selected
      callback()
    switch animation
      when "fade"
        overlayDiv = $(Snippets.maskingOverlay)
        savedSearch.append(overlayDiv)
        fadeAnimation = (_, after) => overlayDiv.fadeTo 100, 0.6, => Util.setTimeout 100, => after()
        Util.runAfterAllAreFinished([fadeAnimation, fetchNewSavedSearch], replaceSavedSearch)
      when "none"
        Util.runAfterAllAreFinished([fetchNewSavedSearch], replaceSavedSearch)

  # Refresh all saved searches using a fade-out animation
  refreshAllSearches: ->
    return if @refreshingAll
    $(".tipsy").remove()
    @refreshingAll = true
    refreshFunctions = for savedSearch in $("#savedSearches .savedSearch")
      # `do` is used to close over the savedSearch in the loop, so that each function retains the correct ref.
      do (savedSearch) => (_, callback) => @refreshSearch($(savedSearch), "fade", callback)
    Util.runAfterAllAreFinished refreshFunctions, => @refreshingAll = false

  # Refresh all saved searches currently sitting on the first page without any animation.
  automaticallyRefreshSearches: ->
    return if @refreshingAll
    @refreshingAll = true
    savedSearches = $("#savedSearches .savedSearch")
    # We'll only refresh searches that are sitting on the first page and have the first diff selected (if any
    # is selected), to avoid interfering with the user navigation.
    canBeRefreshed = (savedSearch) ->
      return false unless savedSearch.find(".pageNumber").text() == "1"
      selected = savedSearch.find(".selected")
      (selected.size() == 0) || selected.is(savedSearch.find(".commitsList tr:first"))
    refreshFunctions = for savedSearch in savedSearches when canBeRefreshed($(savedSearch))
      do (savedSearch) => (_, callback) => @refreshSearch($(savedSearch), "none", callback)
    Util.runAfterAllAreFinished refreshFunctions, => @refreshingAll = false

  beforeSync: ->
    # The right thing to do here is to queue up this state and re-sync when the current sync callback happens.
    if @syncing
      # TODO(caleb): Getting rid of this for now, but we need to think about handling this. The most
      # full-featured option would be displaying some kind of error message to the user and queuing up syncs
      # (a la Gmail), but maybe there's a simpler option.
      #alert "Another sync in progress...server connection problems?"
      return
    @syncing = true

  afterSync: ->
    @syncing = false

$(document).ready(-> CommitSearch.init())

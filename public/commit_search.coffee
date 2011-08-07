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
    $("#savedSearches .savedSearch .pageLeftButton").live "click", (e) => @pageSearch(e, true)
    $("#savedSearches .savedSearch .pageRightButton").live "click", (e) => @pageSearch(e, false)
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
        @pageSearch(event, true)
      when "l"
        @pageSearch(event, false)
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

  pageSearch: (event, reverse = false) ->
    return if @searching
    @searching = true
    if event.type == "keydown"
      savedSearch = $(".selected").parents(".savedSearch")
      keypress = true
    else # event.type == "click"
      savedSearch = $(event.target).parents(".savedSearch")
      keypress = false
    savedSearchId = savedSearch.attr("saved-search-id")
    # Do a click effect on the button
    buttons = $("#savedSearches .savedSearch[saved-search-id=#{savedSearchId}] .pageControls")
    button = if reverse then buttons.find(".pageLeftButton") else buttons.find(".pageRightButton")
    if keypress
      button.addClass("active")
      timeout 70, =>
        button.removeClass("active")

    pageNumber = (Number) savedSearch.attr("page-number")
    pageNumber = if reverse then pageNumber - 1 else pageNumber + 1
    console.log "page saved_search with id #{savedSearchId} to page #{pageNumber}"
    $.ajax
      url: "/saved_searches/#{savedSearchId}?page_number=#{pageNumber}",
      success: (html) =>
        # only update if there are commits for the requested page number
        if $(html).find(".commitsList tr").size() > 0
          $(".savedSearch[saved-search-id=#{savedSearchId}]").replaceWith html
          $(".selected").removeClass "selected"
          $(".savedSearch[saved-search-id=#{savedSearchId}] .commitsList tr:first").addClass "selected"
          buttons = $(".savedSearch[saved-search-id=#{savedSearchId}] .pageControls")
          if pageNumber <= 1
            buttons.find(".pageLeftButton").addClass "disabled"
          # TODO(caleb): Implement counting result size on the server and sending that back to the client, so
          # that we can know how many pages of results there are and when to stop paging properly.
        @searching = false

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

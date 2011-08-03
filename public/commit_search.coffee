# import common.coffee, jquery, and jquery UI

window.CommitSearch =
  init: ->
    $("#commitSearch .submit").click (e) => @onSearchClick e
    $("#commitSearch input[name=filter_value]").focus()
    $("#commitSearch input[name=filter_value]").keydown (e) => @onKeydownInSearchbox e
    $(document).keydown (e) => @onKeydown e
    $("#savedSearches").sortable(
      placeholder: "savedSearchPlaceholder"
      handle: ".handle"
    )
    $("#savedSearches").disableSelection()
    $("#savedSearches .savedSearch .delete").click (e) => @onSavedSearchDelete e
    $("#savedSearches .savedSearch .pageLeftButton").live "click", (e) => @pageSearch(e, true)
    $("#savedSearches .savedSearch .pageRightButton").live "click", (e) => @pageSearch(e, false)
    @selectFirstDiff()

  onSearchClick: ->
    $("#commitSearch input[name=filter_value]").blur()
    authors = $("#commitSearch input[name=filter_value]").val()
    return unless authors
    queryParams = { authors: authors }
    $.post("/saved_searches", queryParams, (e) => @onSearchSaved e)

  onSearchSaved: (responseHtml) ->
    $("#savedSearches").prepend responseHtml
    $("#savedSearches .savedSearch:first-of-type .delete").click (e) => @onSavedSearchDelete e
    @selectFirstDiff()

  onSavedSearchDelete: (event) ->
    target = $(event.target).parents(".savedSearch")
    if $(".selected").parents(".savedSearch").is(target)
      @selectNewGroup(false) unless @selectNewGroup(true)
      removedSelected = true
    target.remove()
    @scrollWithContext() if removedSelected
    # TODO(caleb): save state to the server afterwards (deletes aren't persisted at the moment).
    false

  onKeydownInSearchbox: (event) ->
    event.stopPropagation()
    switch event.which
      when Constants.KEY_RETURN
        @onSearchClick()
      when Constants.KEY_ESC
        $("#commitSearch input[name=filter_value]").blur()
        @scrollWithContext()

  onKeydown: (event) ->
    event.stopPropagation()
    switch event.which
      when Constants.KEY_SLASH
        window.scroll(0, 0)
        $("#commitSearch input[name=filter_value]").focus()
        return false
      when Constants.KEY_J
        @selectDiff(true)
      when Constants.KEY_K
        @selectDiff(false)
      when Constants.KEY_H
        @pageSearch(event, true)
      when Constants.KEY_L
        @pageSearch(event, false)

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
    else # event.type == "click"
      savedSearch = $(event.target).parents(".savedSearch")
    savedSearchId = savedSearch.attr("saved-search-id")
    pageNumber = (Number) savedSearch.attr("page-number")
    pageNumber = if reverse then pageNumber - 1 else pageNumber + 1
    console.log "page saved_search with id " + savedSearchId + " to page " + pageNumber
    $.ajax({
      url: "/saved_searches/" + savedSearchId + "?page_number=" + pageNumber,
      success: (html) =>
        # only update if there are commits for the requested page number
        if $(html).find(".noResults").size() == 0
          $(".savedSearch[saved-search-id=" + savedSearchId + "]").replaceWith(html)
          $(".selected").removeClass("selected")
          $(".savedSearch[saved-search-id=" + savedSearchId + "] .commitsList tr:first").addClass("selected")
        @searching = false
    })

$(document).ready(-> CommitSearch.init())

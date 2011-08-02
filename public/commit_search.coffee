# import common.coffee and jquery

window.CommitSearch =
  init: ->
    $("#commitSearch .submit").click (e) => @onSearchClick e
    $("#commitSearch input[name=filter_value]").focus()
    $("#commitSearch input[name=filter_value]").keydown (e) => @onKeydownInSearchbox e
    $(document).keydown (e) => @onKeydown e
    @selectFirstDiff()

  onSearchClick: ->
    $("#commitSearch input[name=filter_value]").blur()
    authors = $("#commitSearch input[name=filter_value]").val()
    return unless authors
    queryParams = { authors: authors }
    $.post("/saved_searches", queryParams, @onSearchSaved)

  onSearchSaved: (responseHtml) ->
    $("#savedSearches").prepend responseHtml
    @selectFirstDiff()

  onKeydownInSearchbox: (event) ->
    event.stopPropagation()
    switch event.which
      when Constants.KEY_RETURN
        @onSearchClick()
      when Constants.KEY_ESC
        $("#commitSearch input[name=filter_value]").blur()

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

  selectFirstDiff: ->
    $(".selected").removeClass "selected"
    selectedGroup = $(".savedSearch:first-of-type")
    while selectedGroup.size() > 0
      selected = selectedGroup.find(".commitsList tr:first-of-type")
      if selected.size() > 0
        selected.addClass "selected"
        break
      selectedGroup = selectedGroup.next()

  # If true then next; else previous
  selectDiff: (next = true) ->
    selected = $(".selected")
    group = selected.parents(".savedSearch")
    newlySelected = if next then selected.next() else selected.prev()
    while newlySelected.size() == 0
      group = if next then group.next() else group.prev()
      return if group.size() == 0
      newlySelected = if next then group.find("tr:first-of-type") else group.find("tr:last-of-type")
    selected.removeClass "selected"
    newlySelected.addClass "selected"

    # Keep some amount of context on-screen to pad the selection position
    selectionTop = newlySelected.offset().top
    selectionBottom = selectionTop + newlySelected.height()
    windowTop = $(window).scrollTop()
    windowBottom = windowTop + $(window).height()
    if selectionTop - windowTop < Constants.CONTEXT_BUFFER_PIXELS
      window.scroll(0, selectionTop - Constants.CONTEXT_BUFFER_PIXELS)
    else if windowBottom - selectionBottom < Constants.CONTEXT_BUFFER_PIXELS
      window.scroll(0, selectionBottom + Constants.CONTEXT_BUFFER_PIXELS - $(window).height())

$(document).ready(-> CommitSearch.init())

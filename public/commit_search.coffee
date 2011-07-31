# import common.coffee and jquery

CommitSearch =
  init: ->
    $("#commitSearch .submit").click @onSearchClick.proxy(@)
    $("#commitSearch input[name=filter_value]").focus()
    $("#commitSearch input[name=filter_value]").keydown @onKeydownInSearchbox.proxy(@)
    $(document).keydown @onKeydown.proxy(@)
    $(".savedSearch:first-of-type .commitsList tr:first-of-type").addClass "selected"

  onSearchClick: ->
    $("#commitSearch input[name=filter_value]").blur()
    authors = $("#commitSearch input[name=filter_value]").val()
    return unless authors
    queryParams = { authors: authors }
    $.post("/saved_searches", queryParams, @onSearchSaved.proxy(@))

  onSearchSaved: (responseHtml) ->
    $("#savedSearches").prepend responseHtml
    $(".selected").removeClass "selected"
    $(".savedSearch:first-of-type .commitsList tr:first-of-type").addClass "selected"

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
        $("#commitSearch input[name=filter_value]").focus()
        return false
      when Constants.KEY_J
        @selectNextDiff()
      when Constants.KEY_K
        @selectPreviousDiff()

  selectNextDiff: ->
    # TODO(dmac): If a savedSearch group has no diffs, navigation won't skip over it.
    newlySelected = $(".selected").next()
    if newlySelected.size() == 0
      newlySelected = $(".selected").parents(".savedSearch").next().find("tr:first-of-type")
      newlySelected = if newlySelected.size() > 0 then newlySelected else $(".selected")
    $(".selected").removeClass "selected"
    newlySelected.addClass "selected"

  selectPreviousDiff: ->
    # TODO(dmac): If a savedSearch group has no diffs, navigation won't skip over it.
    newlySelected = $(".selected").prev()
    if newlySelected.size() == 0
      newlySelected = $(".selected").parents(".savedSearch").prev().find("tr:last-of-type")
      newlySelected = if newlySelected.size() > 0 then newlySelected else $(".selected")
    $(".selected").removeClass "selected"
    newlySelected.addClass "selected"

$(document).ready(-> CommitSearch.init())

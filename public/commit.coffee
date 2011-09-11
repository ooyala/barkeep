# import common.coffee, jquery, and jquery-json

window.Commit =
  init: ->
    $(document).keydown (e) => @onKeydown e
    $(".diffLine").dblclick (e) => @onDiffLineDblClickOrReply e
    $(".reply").live "click", (e) => @onDiffLineDblClickOrReply e
    $(".diffLine").hover(((e) => @selectLine(e)), ((e) => @clearSelectedLine()))
    $(".commentForm").live "submit", (e) => @onCommentSubmit e
    $("#approveButton").live "click", (e) => @onApproveClicked e
    $("#disapproveButton").live "click", (e) => @onDisapproveClicked e
    $(".delete").live "click", (e) => @onCommentDelete e

  onKeydown: (event) ->
    return unless @beforeKeydown(event)
    switch KeyboardShortcuts.keyCombo(event)
      when "j"
        @selectNextLine(true)
      when "k"
        @selectNextLine(false)
      when "s_n"
        @scrollFile(true)
      when "s_p"
        @scrollFile(false)
      when "e"
        @toggleFullDiff(event)
      when "n"
        @scrollChunk(true)
      when "p"
        @scrollChunk(false)
      when "b"
        @toggleSideBySide(event)
      when "return"
        return if $(".commentCancel").length > 0
        $(".diffLine.selected").dblclick()
      when "escape"
        #TODO(kle): cancel comment forms
        @clearSelectedLine()
      else
        KeyboardShortcuts.globalOnKeydown(event)

  beforeKeydown: (event) ->
    return false if $(document.activeElement).is("textarea")
    KeyboardShortcuts.beforeKeydown(event)

  calculateMarginSize: ->
    commit = $("#commit")
    # We need to add 1 to account for the extra 'diff' character (" ", "+", or "-")
    lineSize = Number(commit.attr("margin-size")) + 1
    maxLengthLine = ("a" for i in [1..lineSize]).join("")
    marginSizingDiv = $("<span id='marginSizing'>#{maxLengthLine}</span>")
    commit.append(marginSizingDiv)
    marginSize = marginSizingDiv.width()
    marginSizingDiv.remove()
    $("#commit .marginLine").css("left", "#{marginSize}px")

  # Returns true if the diff line is within the user's scroll context
  lineVisible: (line,visible = "all") ->
    lineTop = $(line).offset().top
    windowTop = $(window).scrollTop()
    lineBottom = lineTop + $(line).height()
    windowBottom = windowTop + $(window).height()
    switch visible
      when "top" then lineTop >= windowTop
      when "bottom" then lineBottom <= windowBottom
      else lineTop >= windowTop and lineBottom <= windowBottom

  clearSelectedLine: ->
    $(".diffLine.selected").removeClass("selected")

  selectLine: (event) ->
    target = $(event.currentTarget)
    return if target.hasClass("selected")
    @clearSelectedLine()
    target.addClass("selected")

  selectNextVisibleLine: ->
    selectedLine = $(".diffLine.selected")
    visibleLines = $(".diffLine").filter(":visible")
    selectedLine.removeClass("selected")
    select = _(visibleLines).detect((x) => @lineVisible(x,"top"))
    $(select).addClass("selected")

  selectNextLine: (next = true) ->
    selectedLine = $(".diffLine.selected")
    visibleLines = $(".diffLine").filter(":visible")
    if selectedLine.length == 0 or not @lineVisible(selectedLine)
      @selectNextVisibleLine()
    else
      index = _(visibleLines).indexOf(selectedLine[0])
      return if (not next and index == 0) or (next and index == (visibleLines.length - 1))
      selectedLine.removeClass("selected")
      newIndex = if next then index + 1 else index - 1
      $(visibleLines[newIndex]).addClass("selected")
    scroll = if next then "bottom" else "top"
    ScrollWithContext(".diffLine.selected", scroll)


  scrollChunk: (next = true) ->
    @scrollSelector(".diffLine.chunk-start", next)

  scrollFile: (next = true) ->
    @scrollSelector("#commit .file", next)

  scrollSelector: (selector, next = true) ->
    previousPosition = 0
    for selected in $(selector)
      currentPosition = $(selected).offset().top
      if currentPosition < $(window).scrollTop() or ((currentPosition == $(window).scrollTop()) and next)
        previousPosition = currentPosition
      else
        break
    window.scroll(0, if next then currentPosition else previousPosition)
    selectedLine = $(".diffLine.selected")
    return if selectedLine.length == 0 or @lineVisible(selectedLine)
    @selectNextVisibleLine()


  #Logic to add comments
  onDiffLineDblClickOrReply: (e) ->
    if $(e.target).hasClass("delete") then return
    if $(e.target).parents(".diffLine").find(".commentForm").size() > 0 then return
    if $(e.target).hasClass("reply")
      codeLine = $(e.currentTarget).parents(".diffLine").find(".code")
    else
      codeLine = $(e.currentTarget).find(".code")
    lineNumber = codeLine.parents(".diffLine").attr("diff-line-number")
    filename = codeLine.parents(".file").attr("filename")
    sha = codeLine.parents("#commit").attr("sha")
    repoName = codeLine.parents("#commit").attr("repo")
    Commit.createCommentForm(codeLine, repoName, sha, filename, lineNumber)

  createCommentForm: (codeLine, repoName, sha, filename, lineNumber) ->
    $.ajax({
      type: "get",
      url: "/comment_form",
      data: {
        repo_name: repoName,
        sha: sha,
        filename: filename,
        line_number: lineNumber
      },
      success: (html) ->
        commentForm = $(html)
        commentForm.click (e) -> e.stopPropagation()
        commentForm.find(".commentText").keydown (e) -> e.stopPropagation()
        commentForm.find(".commentCancel").click(Commit.onCommentCancel)
        codeLine.append(commentForm)
        commentForm.find(".commentText").focus()
    })

  onCommentSubmit: (e) ->
    e.preventDefault()
    if $(e.currentTarget).find("textarea").val() == ""
      return
    data = {}
    $(e.currentTarget).find("input, textarea").each (i,e) -> data[e.name] = e.value if e.name
    $.ajax
      type: "POST",
      data: data,
      url: e.currentTarget.action,
      success: (html) -> Commit.onCommentSubmitSuccess(html, e.currentTarget)

  onCommentSubmitSuccess: (html, form) ->
    $(form).before(html)
    if $(form).parents(".diffLine").size() > 0
      $(form).remove()
    else
      # Don't remove the comment box if it's for a commit-level comment
      $(form).find("textarea").val("")

  onCommentCancel: (e) ->
    e.stopPropagation()
    $(e.target).parents(".commentForm").remove()

  onCommentDelete: (e) ->
    $.ajax({
      type: "post",
      url: "/delete_comment",
      data: { comment_id: $(e.target).parents(".comment").attr("commentId") },
      success: ->
        $(e.target).parents(".comment").remove()
    })

  onApproveClicked: (e) ->
    $.ajax({
      type: "post",
      url: "/approve_commit",
      data: {
        repo_name: $("#commit").attr("repo")
        commit_sha: $("#commit").attr("sha")
      }
      success: (bannerHtml) ->
        $("#approveButton").replaceWith(bannerHtml)
    })

  onDisapproveClicked: (e) ->
    $.ajax({
      type: "post",
      url: "/disapprove_commit",
      data: {
        repo_name: $("#commit").attr("repo")
        commit_sha: $("#commit").attr("sha")
      }
      success: ->
        $("#approvedBanner").replaceWith("<button id='approveButton' class='fancy'>Approve Commit</button>")
    })

  toggleFullDiff: (event) ->
    # Only toggle the full diff if no other element on the page is selected
    return if $.inArray(event.target.tagName, ["BODY", "HTML"]) == -1
    # Performance optimization: instead of using toggle(), which checks each element if it's visible,
    # only check the first diffLine on the page to see if we need to show() or hide().
    firstNonChunk = $(document).find(".diffLine").not(".chunk").filter(":first")
    firstChunk = $(document).find(".diffLine.chunk:first")
    if firstNonChunk.css("display") == "none"
      $(".chunkBreak").hide()
      $(".diffLine").not(".chunk").show()
      window.scrollTo(0, firstChunk.offset().top)
    else
      $(".diffLine").not(".chunk").hide()
      $(".chunkBreak").show()
      $(".diffLine.selected").filter(":hidden").removeClass("selected")

  toggleSideBySide: (event) ->
    # Only toggle if no other element on the page is selected
    return if $.inArray(event.target.tagName, ["BODY", "HTML"]) == -1

    rightCodeTable = $(".codeRight")
    leftCodeTable = $(".codeLeft")
    if rightCodeTable.css("display") == "none"
      # Set the width so that the numbers columns from right table end up in the middle
      # Left table needs to be shorter because of the hidden number columns
      numberColumnWidth = $(".leftNumber").outerWidth()
      originalLeftWidth = leftCodeTable.width()
      finalLeftWidth = originalLeftWidth - 2 * numberColumnWidth
      rightCodeTable.width(originalLeftWidth)
      leftCodeTable.width(originalLeftWidth)

      # show and hide the appropriate elements in the 2 tables
      $(".leftNumber").hide()
      leftCodeTable.find(".added").css("visibility", "hidden")
      rightCodeTable.show()
      rightCodeTable.find(".removed").css("visibility", "hidden")

      # animations to split the 2 tables
      # TODO(bochen): don't animate when there are too many lines on the page (its too slow)
      $(document.body).animate("width": 2 * $("body").width() - 2 * numberColumnWidth, 1000)
      leftCodeTable.animate("width": finalLeftWidth, 1000)
      rightCodeTable.animate("left": finalLeftWidth, 1000)
    else
      # callapse to unified diff

$(document).ready(-> Commit.init())
# This needs to happen on page load because we need the styles to be rendered.
$(window).load(-> Commit.calculateMarginSize())

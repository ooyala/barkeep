# import common.coffee, jquery, and jquery-json

window.Commit =
  init: ->
    $(document).keydown (e) => @onKeydown e
    $(".diffLine").dblclick(Commit.onDiffLineDblClick)
    $(".diffLine").hover(((e) => @selectLine(e)), ((e) => @clearSelectedLine()))
    $(".commentForm").live "submit", (e) => @onCommentSubmit e
    $("#approveButton").live "click", (e) => @onApproveClicked e
    $("#disapproveButton").live "click", (e) => @onDisapproveClicked e
    $(".delete").live "click", (e) => @onCommentDelete e

  onKeydown: (event) ->
    return unless KeyboardShortcuts.beforeKeydown(event)
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
        @toggleFullDiff()
      when "n"
        @scrollChunk(true)
      when "p"
        @scrollChunk(false)
      when "return"
        return if $(".commentCancel").length > 0
        $(".diffLine.selected").dblclick()
      when "escape"
        #TODO(kle): cancel comment forms
        @clearSelectedLine()
      else
        KeyboardShortcuts.globalOnKeydown(event)

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

  selectNextLine: (next = true) ->
    selectedLine = $(".diffLine.selected")
    visibleLines = $(".diffLine").filter(":visible")
    if selectedLine.length == 0 or not @lineVisible(selectedLine)
      selectedLine.removeClass("selected")
      select = _(visibleLines).detect((x) => @lineVisible(x,"top"))
      $(select).addClass("selected")
    else
      index = _(visibleLines).indexOf(selectedLine[0])
      return if (not next and index == 0) or (next and index == (visibleLines.length - 1))
      selectedLine.removeClass("selected")
      newIndex = if next then index + 1 else index - 1
      $(visibleLines[newIndex]).addClass("selected")
    ScrollWithContext(".diffLine.selected")


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

  #Logic to add comments
  onDiffLineDblClick: (e) ->
    if $(e.target).hasClass("delete") then return
    if $(e.target).parents(".diffLine").find(".commentForm").size() > 0 then return
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

  toggleFullDiff: ->
    # Performance optimization: instead of using toggle(), which checks each element if it's visible,
    # only check the first diffLine on the page to see if we need to show() or hide().
    firstNonChunk = $(document).find(".diffLine").not(".chunk").filter(":first")
    firstChunk = $(document).find(".diffLine.chunk:first")
    if firstNonChunk.css("display") == "none"
      $(".diffLine").not(".chunk").show()
      window.scrollTo(0, firstChunk.offset().top)
    else
      $(".diffLine").not(".chunk").hide()
      $(".diffLine.selected").filter(":hidden").removeClass("selected")

$(document).ready(-> Commit.init())

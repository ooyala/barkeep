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
        $(".diffLine.selected").first().dblclick()
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
      lineNumber = $(e.currentTarget).parents(".diffLine").attr("diff-line-number")
    else
      lineNumber = $(e.currentTarget).attr("diff-line-number")

    #select line and add form to both left and right tables (so that the length of them stay the same
    codeLine = $(e.target).parents(".file").find(".diffLine[diff-line-number='" + lineNumber + "'] .code")
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
        #add a random id so matching comments on both sides of side-by-side can be shown
        commentForm.attr("form-id", Math.floor(Math.random()*10000) )
        commentForm.find(".commentText").keydown (e) -> e.stopPropagation()
        commentForm.find(".commentCancel").click(Commit.onCommentCancel)
        codeLine.append(commentForm)
        Commit.setSideBySideCommentVisibility()
        codeLine.find(".commentForm").first().find(".commentText").focus()
    })

  onCommentSubmit: (e) ->
    e.preventDefault()
    if $(e.currentTarget).find("textarea").val() == ""
      return
    #make sure changes to form happen to both tables to maintain height
    formId = $(e.currentTarget).attr("form-id")
    form = $(e.currentTarget).parents(".file").find(".commentForm[form-id='" + formId + "']")
    data = {}
    $(e.currentTarget).find("input, textarea").each (i,e) -> data[e.name] = e.value if e.name
    $.ajax
      type: "POST",
      data: data,
      url: e.currentTarget.action,
      success: (html) -> Commit.onCommentSubmitSuccess(html, form)

  onCommentSubmitSuccess: (html, form) ->
    $(form).before(html)
    if $(form).parents(".diffLine").size() > 0
      $(form).remove()
      Commit.setSideBySideCommentVisibility()
    else
      # Don't remove the comment box if it's for a commit-level comment
      $(form).find("textarea").val("")

  onCommentCancel: (e) ->
    e.stopPropagation()
    #make sure changes to form happen to both tables to maintain height
    formId = $(e.currentTarget).parents(".commentForm").attr("form-id")
    form = $(e.currentTarget).parents(".file").find(".commentForm[form-id='" + formId + "']")
    form.remove()
    Commit.setSideBySideCommentVisibility()

  onCommentDelete: (e) ->
    commentId = $(e.target).parents(".comment").attr("commentId")
    $.ajax({
      type: "post",
      url: "/delete_comment",
      data: { comment_id: commentId },
      success: ->
        #make sure changes to form happen to both tables to maintain height
        form = $(e.currentTarget).parents(".file").find(".comment[commentId='" + commentId + "']")
        form.remove()
        Commit.setSideBySideCommentVisibility()
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
    return if $(".codeRight").filter(":animated").length > 0
    # Only toggle if no other element on the page is selected
    return if $.inArray(event.target.tagName, ["BODY", "HTML"]) == -1

    rightCodeTable = $(".codeRight")
    leftCodeTable = $(".codeLeft")
    unless Commit.isSideBySide
      Commit.isSideBySide = true
      originalLeftWidth = leftCodeTable.width()
      rightCodeTable.width(originalLeftWidth)
      leftCodeTable.width(originalLeftWidth)

      # show and hide the appropriate elements in the 2 tables
      rightCodeTable.show()
      leftCodeTable.find(".added > .codeText").css("visibility", "hidden")
      rightCodeTable.find(".removed > .codeText").css("visibility", "hidden")
      leftCodeTable.find(".rightNumber").hide()
      rightCodeTable.find(".leftNumber").hide()
      Commit.setSideBySideCommentVisibility()

      # animations to split the 2 tables
      # TODO(bochen): don't animate when there are too many lines on the page (its too slow)
      $(document.body).animate("width": $("body").width() * 2 - 2, 1000 )
      rightCodeTable.animate("left": originalLeftWidth, 1000)
    else
      Commit.isSideBySide = false
      # callapse to unified diff
      $(document.body).animate("width": $("body").width() / 2 + 1, 1000, -> Commit.onSideBySideCallapsed() )
      rightCodeTable.animate("left": 0, 1000)


  #set the correct visibility for comments in side By side
  setSideBySideCommentVisibility: () ->
    if Commit.isSideBySide
      $(".codeLeft .comment").css("visibility", "hidden")
      $(".codeLeft .commentForm").css("visibility", "hidden")
      $(".codeLeft .removed .comment").css("visibility", "visible")
      $(".codeLeft .removed .commentForm").css("visibility", "visible")

      $(".codeRight .comment").css("visibility", "visible")
      $(".codeRight .commentForm").css("visibility", "visible")
      $(".codeRight .removed .comment").css("visibility", "hidden")
      $(".codeRight .removed .commentForm").css("visibility", "hidden")
    else
      $(".codeLeft .comment").css("visibility", "visible")
      $(".codeLeft .commentForm").css("visibility", "visible")
      $(".codeRight .comment").css("visibility", "hidden")
      $(".codeRight .commentForm").css("visibility", "hidden")

  #after the side-by-side callapse animation is done, reset everything to the way it should be for unified diff
  onSideBySideCallapsed: () ->
    $(".codeLeft .added > .codeText").css("visibility", "visible")
    Commit.setSideBySideCommentVisibility()
    $(".codeRight").hide()
    $(".codeLeft .rightNumber").show()

$(document).ready(-> Commit.init())
# This needs to happen on page load because we need the styles to be rendered.
$(window).load(-> Commit.calculateMarginSize())

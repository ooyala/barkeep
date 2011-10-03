window.Commit =
  SIDE_BY_SIDE_SLIDE_DURATION: 300
  SIDE_BY_SIDE_SPLIT_DURATION: 700
  SIDE_BY_SIDE_COOKIE: "sideBySide"

  init: ->
    $(document).keydown (e) => @onKeydown e
    $(".diffLine").dblclick (e) => @onDiffLineDblClickOrReply e
    $(".reply").live "click", (e) => @onDiffLineDblClickOrReply e
    $(".diffLine").hover(((e) => @selectLine(e)), ((e) => @clearSelectedLine()))
    $(".commentForm").live "submit", (e) => @onCommentSubmit e
    $(".commentEditForm").live "submit", (e) => @onCommentEditSubmit e
    $("#approveButton").live "click", (e) => @onApproveClicked e
    $("#disapproveButton").live "click", (e) => @onDisapproveClicked e
    $(".delete").live "click", (e) => @onCommentDelete e
    $(".edit").live "click", (e) => @onCommentEdit e
    # eventually this should be a user preference stored server side, for now. Its just a cookie
    @toggleSideBySide(false) if readCookie(@.SIDE_BY_SIDE_COOKIE) == "true"

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
        @handleSideBySideKeyPress(event)
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
    lineSize = parseInt(commit.attr("margin-size")) + 1
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
    if Commit.isSideBySide
      visibleLines = visibleLines.filter("[replace='false']")
    selectedLine.removeClass("selected")
    select = _(visibleLines).detect((x) => @lineVisible(x,"top"))
    $(select).addClass("selected")

  selectNextLine: (next = true) ->
    selectedLine = $(".diffLine.selected")
    visibleLines = $(".diffLine").filter(":visible")
    if Commit.isSideBySide
      visibleLines = visibleLines.filter("[replace='false']")
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
    window.getSelection().removeAllRanges() unless e.target.tagName.toLowerCase() in ["input", "textarea"]
    if $(e.target).is(".delete, .edit, .commentText, .commentSubmit") then return
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

  onCommentEdit: (e) ->
    # Use the comment ID instead of generating form ID since left and right tables have the same comments
    comment = $(".comment[commentId='#{$(e.target).parents(".comment").attr("commentId")}']")
    if comment.find(".commentEditForm").size() > 0 then return
    commentEdit = $(CommentForm.create(true, true))
    commentEdit.find(".commentText").html($(e.target).parents(".comment").data("commentRaw"))
    commentEdit.find(".commentCancel").click(Commit.onCommentEditCancel)
    comment.append(commentEdit).find(".commentBody").hide()
    comment.find(".commentText").focus()

  onCommentEditCancel: (e) ->
    comment = $(".comment[commentId='#{$(e.target).parents(".comment").attr("commentId")}']")
    comment.find(".commentEditForm").remove()
    comment.find(".commentBody").show()

  onCommentEditSubmit: (e) ->
    e.preventDefault()
    target = $(e.currentTarget)
    text = target.find(".commentText").val()
    if text == "" then return
    commentId = target.parents(".comment").attr("commentId")
    $.ajax
      type: "post",
      url: e.currentTarget.action,
      data: {
        comment_id: commentId
        text: text
      },
      success: (html) ->
        comment = $(".comment[commentId='#{commentId}']")
        comment.data("commentRaw", text)
        comment.find(".commentBody").html(html)
        comment.find(".commentCancel").click()

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
        commentForm.attr("form-id", Math.floor(Math.random() * 10000))
        commentForm.find(".commentText").keydown (e) -> e.stopPropagation()
        commentForm.find(".commentCancel").click(Commit.onCommentCancel)
        codeLine.append(commentForm)
        Commit.setSideBySideCommentVisibility()
        codeLine.find(".commentForm").first().find(".commentText").focus()
    })

  onCommentSubmit: (e) ->
    e.preventDefault()
    target = $(e.currentTarget)
    if target.find("textarea").val() == ""
      return
    #make sure changes to form happen to both tables to maintain height
    formId = target.attr("form-id")
    file = target.parents(".file")
    # file is the parent file for the comment, if the comment is a line-level comment.
    form = if file.size() > 0 then file.find(".commentForm[form-id='" + formId + "']") else target
    data = {}
    target.find("input, textarea").each (i,e) -> data[e.name] = e.value if e.name
    $.ajax
      type: "POST",
      data: data,
      url: e.currentTarget.action,
      success: (html) => @onCommentSubmitSuccess(html, form)

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
    $.ajax
      type: "post",
      url: "/delete_comment",
      data: { comment_id: commentId },
      success: =>
        # Make sure that changes to forms happen to both tables to maintain height if deleting a line comment.
        target = $(e.currentTarget)
        file = target.parents(".file")
        if file.size() > 0
          form = file.find(".comment[commentid='" + commentId + "']")
        else
          form = target.parents(".comment")
        form.remove()
        @setSideBySideCommentVisibility()

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

      # Hiding and showing the .chunk-start lines is a hack to make them re-render properly in Webkit.
      # Worse, the only way I could get it to work is by introducing a very slight delay (the 1ms argument to
      # show().
      #
      # TODO(caleb): Figure out a less hacky solution
      $(".diffLine.chunk-start").hide()
      $(".diffLine.chunk-start").show(1)

      window.scrollTo(0, firstChunk.offset().top)
    else
      $(".diffLine").not(".chunk").hide()
      $(".chunkBreak").show()
      $(".diffLine.selected").filter(":hidden").removeClass("selected")

  handleSideBySideKeyPress: (event) ->
    # Only toggle if no other element on the page is selected
    return if $.inArray(event.target.tagName, ["BODY", "HTML"]) == -1
    @toggleSideBySide(true)


  toggleSideBySide: (animate = true) ->
    return if $(".slideDiv, body, .codeRight").filter(":animated").length > 0

    # for now, use the jquery.fx.off switch to make sidebyside toggle without animations.
    originalJQueryFxOff = jQuery.fx.off
    jQuery.fx.off = !animate

    rightCodeTable = $(".codeRight")
    leftCodeTable = $(".codeLeft")
    unless Commit.isSideBySide
      # split to side-by-side
      Commit.isSideBySide = true
      createCookie @.SIDE_BY_SIDE_COOKIE, "true", 2^30
      # save off size of code table so it doesn't drift after many animations
      Commit.originalLeftWidth ?= leftCodeTable.width()
      Commit.originalContainerWidth ?= $("#container").width()
      rightCodeTable.width(Commit.originalLeftWidth)
      leftCodeTable.width(Commit.originalLeftWidth)

      # show and hide the appropriate elements in the 2 tables
      rightCodeTable.show()
      leftCodeTable.find(".added > .codeText").css({"visibility": "hidden"})
      rightCodeTable.find(".removed > .codeText").css({"visibility": "hidden"})
      leftCodeTable.find(".rightNumber").hide()
      rightCodeTable.find(".leftNumber").hide()
      Commit.setSideBySideCommentVisibility()

      # animations to split the 2 tables
      # TODO(bochen): don't animate when there are too many lines on the page (its too slow)
      rightCodeTable.animate({"left": @.originalLeftWidth},  @.SIDE_BY_SIDE_SPLIT_DURATION)
      $("#container").animate({"width": @.originalContainerWidth * 2 - 2},
        @.SIDE_BY_SIDE_SPLIT_DURATION)
      # slide up the replaced rows
      Util.animateTimeout @.SIDE_BY_SIDE_SPLIT_DURATION, () ->
        $(".diffLine[replace='true'] .slideDiv").slideUp @.SIDE_BY_SIDE_SLIDE_DURATION
        leftCodeTable.find(".diffLine[tag='added'][replace='false']").addClass "spacingLine"
        rightCodeTable.find(".diffLine[tag='removed'][replace='false']").addClass "spacingLine"
      Util.animateTimeout @.SIDE_BY_SIDE_SPLIT_DURATION + @.SIDE_BY_SIDE_SLIDE_DURATION, () =>
        jQuery.fx.off = originalJQueryFxOff
    else
      # callapse to unified diff
      Commit.isSideBySide = false
      createCookie @.SIDE_BY_SIDE_COOKIE, "false", 2^30
      $(".diffLine[replace='true'] .slideDiv").slideDown(@.SIDE_BY_SIDE_SLIDE_DURATION)
      $(".diffLine[replace='true']").slideDown(@.SIDE_BY_SIDE_SLIDE_DURATION)
      Util.animateTimeout @.SIDE_BY_SIDE_SLIDE_DURATION, () =>
        rightCodeTable.find(".diffLine[tag='removed']").removeClass "spacingLine"
        leftCodeTable.find(".diffLine[tag='added']").removeClass "spacingLine"
      rightCodeTable.delay(@.SIDE_BY_SIDE_SLIDE_DURATION).animate({ "left": 0 },
          @.SIDE_BY_SIDE_SPLIT_DURATION)
      $("#container").delay(@.SIDE_BY_SIDE_SLIDE_DURATION).
          animate {"width": @.originalContainerWidth}, @.SIDE_BY_SIDE_SPLIT_DURATION, () =>
            # after the side-by-side callapse animation is done,
            #  reset everything to the way it should be for unified diff
            $(".codeLeft .added > .codeText").css("visibility", "visible")
            @.setSideBySideCommentVisibility()
            $(".codeRight").hide()
            $(".codeLeft .rightNumber").show()
            jQuery.fx.off = originalJQueryFxOff

  #set the correct visibility for comments in side By side
  setSideBySideCommentVisibility: () ->
    rightCodeTable = $(".codeRight")
    leftCodeTable = $(".codeLeft")
    if Commit.isSideBySide
      leftCodeTable.find(".comment, .commentForm").css("visibility": "hidden")
      leftCodeTable.find(".removed").find(".comment, .commentForm").css("visibility", "visible")

      rightCodeTable.find(".comment, .commentForm").css("visibility", "visible")
      rightCodeTable.find(".removed").find(".comment, .commentForm").css("visibility", "hidden")
    else
      leftCodeTable.find(".comment, .commentForm").css("visibility", "visible")
      rightCodeTable.find(".comment, .commentForm").css("visibility", "hidden")

$(document).ready(-> Commit.init())
# This needs to happen on page load because we need the styles to be rendered.
$(window).load(-> Commit.calculateMarginSize())

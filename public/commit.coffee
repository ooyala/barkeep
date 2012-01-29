window.Commit =
  SIDE_BY_SIDE_SLIDE_DURATION: 300
  SIDE_BY_SIDE_SPLIT_DURATION: 700
  SIDE_BY_SIDE_CODE_WIDTH: 830
  SIDE_BY_SIDE_COOKIE: "sideBySide"

  init: ->
    $(".diffLine").dblclick (e) => @onDiffLineDblClickOrReply e
    $(".reply").live "click", (e) => @onDiffLineDblClickOrReply e
    $(".diffLine").hover(((e) => @selectLine(e)), ((e) => @clearSelectedLine()))
    $(".commentForm").live "submit", (e) => @onCommentSubmit e
    $(".commentPreview").click (e) => @onCommentPreview e
    $(".commentEditForm").live "submit", (e) => @onCommentEditSubmit e
    $("#approveButton").live "click", (e) => @onApproveClicked e
    $("#disapproveButton").live "click", (e) => @onDisapproveClicked e
    $(".delete").live "click", (e) => @onCommentDelete e
    $(".edit").live "click", (e) => @onCommentEdit e
    $("#sideBySideButton").live "click", => @toggleSideBySide true
    $("#requestReviewButton").click (e) => @toggleReviewRequest()
    $("#requestInput button").click (e) => @submitReviewRequest()
    $(".expandLink.all").click (e) => @expandContextAll(e)
    $(".expandLink.below").click (e) => @expandContext(e, 10, "below")
    $(".expandLink.above").click (e) => @expandContext(e, 10, "above")

    commitComment = $("#commitComments .commentText")
    KeyboardShortcuts.createShortcutContext commitComment
    KeyboardShortcuts.registerShortcut commitComment, "esc", => commitComment.blur()
    KeyboardShortcuts.registerShortcut commitComment, "ctrl+p", (e) =>
      $(e.target).parents(".commentForm").find(".commentPreview").click()
      # Prevent side effects such as cursor movement.
      false

    shortcuts =
      "a": => @approveOrDisapprove()
      "j": => @selectNextLine true
      "k": => @selectNextLine false
      "shift+n": => @scrollFile true
      "shift+p": => @scrollFile false
      "e": => @toggleFullDiff()
      "n": => @scrollChunk true
      "p": => @scrollChunk false
      "b": => @toggleSideBySide true
      "r": => @toggleReviewRequest(true)
      "shift+c": =>
        commitComment.focus()
        false
      "return": => $(".diffLine.selected").first().dblclick() unless $(".commentCancel").length > 0
      # TODO(kle): cancel comment forms
      "esc": => @clearSelectedLine()

    KeyboardShortcuts.registerPageShortcut(shortcut, action) for shortcut, action of shortcuts
    reviewRequestInput = $("#reviewRequest #authorInput")

    KeyboardShortcuts.createShortcutContext reviewRequestInput
    KeyboardShortcuts.registerShortcut reviewRequestInput, "return", =>
      @submitReviewRequest() unless $(".ui-autocomplete").is(":visible")
    KeyboardShortcuts.registerShortcut reviewRequestInput, "esc", =>
      @toggleReviewRequest()
      # Return false to prevent clearing the text box.
      false

    # Eventually this should be a user preference stored server side. For now, it's just a cookie.
    @toggleSideBySide(false) if $.cookies(@SIDE_BY_SIDE_COOKIE) == "true"

    # Put the approval overlay message div on the page.
    $("body").append $(Snippets.approvalOverlay)

    # Review request author autocompletion
    $("#reviewRequest #authorInput").autocomplete
      source: (request, callback) ->
        substringMatch = $("#authorInput").val().match(/(^([^,]*)$|,\s*([^,]*)$)/)
        substring = substringMatch[2] || substringMatch[3]
        $.ajax
          type: "get"
          url: "/autocomplete/users"
          data: { substring: substring }
          dataType: "json"
          success: (completion) -> callback(completion.values)
          error: -> callback ""
      select: (event, ui) ->
        # The focus event already populated the input,
        # so we don't need to change anything here.
        false
      focus: (event, ui) ->
        # Match all emails input so far, retrieve the email of the
        # currently selected user, and set the input value as the
        # concatenation of the two.
        prefix = $("#authorInput").val().match(/(.*)(,|^)/)[1]
        prefix = "#{prefix}, " unless prefix == ""
        selection = ui.item.label.match(/<([^>]+)>/)[1] + ", "
        $("#authorInput").val("#{prefix}#{selection}")
        false
      search: (event, ui) ->
        # Don't attempt to search if the input value ends with a comma and whitespace.
        false if $("#authorInput").val().match(/,\s*$/)

  calculateMarginSize: ->
    commit = $("#commit")
    # We need to add 1 to account for the extra 'diff' character (" ", "+", or "-")
    lineSize = parseInt(commit.attr("margin-size")) + 1
    maxLengthLine = ("a" for i in [1..lineSize]).join("")
    marginSizer = $(Snippets.marginSizer(maxLengthLine))
    commit.append(marginSizer)
    marginSize = marginSizer.width()
    marginSizer.remove()
    $("#commit .marginLine").css("left", "#{marginSize}px")

  # Display a popup prompt when the user hits 'a' to confirm that they want to approve.
  approveOrDisapprove: ->
    if $("#approveButton").size() > 0
      choice = "approve"
    else if $("#disapproveButton").size() > 0
      choice = "disapprove"
    else
      return
    approvalOverlay = $(".approvalPopup.overlay")
    approvalOverlay.css("visibility", "visible")
    approvalPopup = $(".approvalPopup.overlay .container")
    approvalPopup.append $(Snippets.approvalPopup(choice))
    KeyboardShortcuts.createShortcutContext approvalPopup
    approvalPopup.blur ->
      approvalPopup.empty()
      approvalOverlay.css("visibility", "hidden")
    KeyboardShortcuts.registerShortcut approvalPopup, "esc", ->
      approvalPopup.blur()
      false
    KeyboardShortcuts.registerShortcut approvalPopup, "a", ->
      approvalPopup.blur()
      $("#approveButton, #disapproveButton").click()
      false
    approvalPopup.focus()

  # Returns true if the diff line is within the user's scroll context
  lineVisible: (line, visible = "all") ->
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
    if @isSideBySide
      visibleLines = visibleLines.filter("[replace='false']")
    selectedLine.removeClass("selected")
    select = _(visibleLines).detect((x) => @lineVisible(x,"top"))
    $(select).addClass("selected")

  selectNextLine: (next = true) ->
    selectedLine = $(".diffLine.selected")
    visibleLines = $(".diffLine").filter(":visible")
    if @isSideBySide
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
    Util.scrollWithContext(".diffLine.selected", scroll)


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
    return if selectedLine.length == 0 or @linenewCodeWidthVisible(selectedLine)
    @selectNextVisibleLine()


  expandContextAll: (event) ->
    expander = $(event.currentTarget).closest(".contextExpander")
    prev = expander.prev()
    if prev.is(":visible")
      diffLines = expander.nextUntil(":visible")
    else
      diffLines = expander.prevUntil(":visible")
    diffLines.show()
    expander.remove()

  expandContext: (event, count, direction) ->
    expander = $(event.currentTarget).closest(".contextExpander")
    if expander.prev().is(":visible")
      lineRange = expander.nextUntil(":visible")
    else
      lineRange = $(expander.prevUntil(":visible").toArray().reverse())
    [rangeToExpand, attachLine, attachDirection] = @getContextRangeToExpand(lineRange, count, direction)
    expander.remove()
    rangeToExpand.show()
    top = attachDirection == "above" && attachLine.prev(":visible").length == 0
    bottom = attachDirection == "below" && attachLine.next(":visible").length == 0
    incremental = lineRange.length - rangeToExpand.length > 10
    @createContextExpander(attachLine, attachDirection, top, bottom, incremental)

  getContextRangeToExpand: (range, count, direction) ->
    if direction == "above"
      rangeToExpand = range.slice(0, count)
      attachLine = rangeToExpand.last()
      [rangeToExpand, attachLine, "below"]
    else
      rangeToExpand = range.slice(-count)
      attachLine = rangeToExpand.first()
      [rangeToExpand, attachLine, "above"]

  createContextExpander: (codeLine, attachDirection, top, bottom, incremental) ->
    $.ajax
      type: "get"
      url: "/context_expander"
      data:
        top: top
        bottom: bottom
        incremental: incremental
      success: (html) =>
        contextExpander = $(html)
        contextExpander.find(".expandLink.all").click (e) => @expandContextAll(e)
        contextExpander.find(".expandLink.above").click (e) => @expandContext(e, 10, "above")
        contextExpander.find(".expandLink.below").click (e) => @expandContext(e, 10, "below")
        codeLine.before(contextExpander) if attachDirection == "above"
        codeLine.after(contextExpander) if attachDirection == "below"

  onDiffLineDblClickOrReply: (e) ->
    window.getSelection().removeAllRanges() unless e.target.tagName.toLowerCase() in ["input", "textarea"]
    return if $(e.target).is(".delete, .edit, .commentText, .commentSubmit")
    return if $(e.target).parents(".diffLine").find(".commentForm").size() > 0
    return unless window.userLoggedIn

    if $(e.target).hasClass("reply")
      lineNumber = $(e.currentTarget).parents(".diffLine").attr("diff-line-number")
    else
      lineNumber = $(e.currentTarget).attr("diff-line-number")

    # Select line and add form to both left and right tables (so that the length of them stay the same).
    codeLine = $(e.target).parents(".file").find(".diffLine[diff-line-number='" + lineNumber + "'] .code")
    filename = codeLine.parents(".file").attr("filename")
    sha = codeLine.parents("#commit").attr("sha")
    repoName = codeLine.parents("#commit").attr("repo")
    @createCommentForm(codeLine, repoName, sha, filename, lineNumber)

  onCommentEdit: (e) ->
    # Use the comment ID instead of generating form ID since left and right tables have the same comments.
    comment = $(".comment[commentId='#{$(e.target).parents(".comment").attr("commentId")}']")
    if comment.find(".commentEditForm").size() > 0 then return
    commentEdit = $(Snippets.commentForm(true, true))
    commentEdit.find(".commentText").html($(e.target).parents(".comment").data("commentRaw"))
    commentEdit.find(".commentCancel").click @onCommentEditCancel
    comment.append(commentEdit).find(".commentBody").hide()
    textarea = comment.find(".commentText")
    KeyboardShortcuts.createShortcutContext textarea
    textarea.focus()
    KeyboardShortcuts.registerShortcut textarea, "esc", => textarea.blur()

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

  # TODO(caleb): Add a Snippet for comment forms instead of contacting the server (there's no server logic
  # needed here).
  createCommentForm: (codeLine, repoName, sha, filename, lineNumber) ->
    $.ajax
      type: "get"
      url: "/comment_form"
      data:
        repo_name: repoName
        sha: sha
        filename: filename
        line_number: lineNumber
      success: (html) =>
        commentForm = $(html)
        commentForm.click (e) -> e.stopPropagation()
        # Add a random id so matching comments on both sides of side-by-side can be shown.
        commentForm.attr("form-id", Math.floor(Math.random() * 10000))
        commentForm.find(".commentCancel").click @onCommentCancel
        commentForm.find(".commentPreview").click @onCommentPreview
        codeLine.append(commentForm)
        @setSideBySideCommentVisibility()
        textarea = codeLine.find(".commentForm .commentText").filter(-> $(@).css("visibility") == "visible")
        KeyboardShortcuts.createShortcutContext textarea
        textarea.focus()
        KeyboardShortcuts.registerShortcut textarea, "esc", => textarea.blur()
        KeyboardShortcuts.registerShortcut textarea, "ctrl+shift+p", (e) =>
          $(e.target).parents(".commentForm").find(".commentPreview").click()
          # Prevent side effects such as cursor movement.
          false

  onCommentSubmit: (e) ->
    e.preventDefault()
    target = $(e.currentTarget)
    if target.find("textarea").val() == ""
      return
    # Make sure changes to form happen to both tables to maintain height.
    formId = target.attr("form-id")
    file = target.parents(".file")
    # File is the parent file for the comment if the comment is a line-level comment.
    form = if file.size() > 0 then file.find(".commentForm[form-id='" + formId + "']") else target
    data = {}
    target.find("input, textarea").each (i,e) -> data[e.name] = e.value if e.name
    $.ajax
      type: "POST",
      data: data,
      url: e.currentTarget.action,
      success: (html) => @onCommentSubmitSuccess(html, form)

  onCommentSubmitSuccess: (html, formElement) ->
    form = $(formElement)
    form.before(html)
    if form.parents(".diffLine").size() > 0
      form.remove()
      @setSideBySideCommentVisibility()
    else
      # Don't remove the comment box if it's for a commit-level comment. We need to get rid of the preview box
      # if that is showing, however.
      preview = form.find(".commentPreviewText")
      textarea = form.find("textarea")
      textarea.val("")
      if preview.is(":visible")
        preview.hide()
        textarea.show()
        form.find(".commentPreview").val("Preview Comment")

  onCommentCancel: (e) ->
    e.stopPropagation()
    # Make sure changes to form happen to both tables to maintain height.
    formId = $(e.currentTarget).parents(".commentForm").attr("form-id")
    form = $(e.currentTarget).parents(".file").find(".commentForm[form-id='" + formId + "']")
    form.remove()
    @setSideBySideCommentVisibility()

  # Toggle preview/editing mode
  onCommentPreview: (e) ->
    e.stopPropagation()
    comment = $(e.target).parents(".commentForm")
    preview = comment.find(".commentPreviewText")
    textarea = comment.find(".commentText")
    previewButton = comment.find(".commentPreview")
    if preview.is(":visible")
      preview.hide()
      textarea.show()
      previewButton.val("Preview Comment")
    else
      return if $.trim(textarea.val()) == ""
      $.ajax
        type: "post",
        url: "/comment_preview",
        data: { text: textarea.val(), sha: $("#commit").attr("sha"), repo_name: $("#commit").attr("repo") }
        success: (rendered) =>
          preview.html(rendered)
          textarea.hide()
          previewButton.val("Continue Editing")
          preview.show()

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
        $("#approveButton").replaceWith(Snippets.disapproveButton)
        $("#disapproveButton").after(bannerHtml)
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
        $("#disapproveButton").replaceWith(Snippets.approveButton)
        $("#approvedBanner").remove()
    })

  toggleFullDiff: ->
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

  toggleSideBySide: (animate = true) ->
    return if @sideBySideAnimating
    @sideBySideAnimating = true
    # for now, use the jquery.fx.off switch to make sidebyside toggle without animations.
    originalJQueryFxOff = jQuery.fx.off
    jQuery.fx.off = !animate

    rightCodeTable = $(".codeRight")
    leftCodeTable = $(".codeLeft")
    container = $("#container")
    unless @isSideBySide
      @isSideBySide = true
      $("div.file").addClass("sideBySide")
      $.cookies(@SIDE_BY_SIDE_COOKIE, "true")
      $("#sideBySideButton").text("View Unified")

      # Save size of the code table so it doesn't drift after many animations.
      @originalLeftWidth ?= leftCodeTable.width()
      @originalContainerWidth ?= container.width()
      @numberColumnOuterWidth ?= leftCodeTable.find(".leftNumber").outerWidth()
      @numberColumnWidth ?= leftCodeTable.find(".leftNumber").width()
      leftCodeTable.width(@originalLeftWidth)
      rightCodeTable.css("left" : @numberColumnOuterWidth)
      rightCodeTable.width(@originalLeftWidth - @numberColumnOuterWidth)

      # show and hide the appropriate elements in the 2 tables
      rightCodeTable.show()
      leftCodeTable.find(".added > .codeText").css(visibility: "hidden")
      rightCodeTable.find(".removed > .codeText").css(visibility: "hidden")
      leftCodeTable.find(".rightNumber").hide()
      rightCodeTable.find(".leftNumber").hide()
      @setSideBySideCommentVisibility()

      # animations to split the 2 tables
      # TODO(bochen): don't animate when there are too many lines on the page (it's too slow).
      newCodeWidth = @SIDE_BY_SIDE_CODE_WIDTH
      rightCodeTable.animate({ "left": newCodeWidth, "width": newCodeWidth },  @SIDE_BY_SIDE_SPLIT_DURATION)
      leftCodeTable.animate({ "width" : newCodeWidth }, @SIDE_BY_SIDE_SPLIT_DURATION)
      container.animate({ "width": newCodeWidth * 2 + 2 }, @SIDE_BY_SIDE_SPLIT_DURATION)
      # jQuery sets this to "hidden" while animating width. We don't want to hide our logo, which overflows.
      container.css("overflow", "visible")
      # slide up the replaced rows
      Util.animateTimeout @SIDE_BY_SIDE_SPLIT_DURATION, ->
        $(".diffLine[replace='true'] .slideDiv").slideUp @SIDE_BY_SIDE_SLIDE_DURATION
        # Add grey background to spacing lines
        leftCodeTable.find(".diffLine[tag='added'][replace='false']").addClass "spacingLine"
        rightCodeTable.find(".diffLine[tag='removed'][replace='false']").addClass "spacingLine"
      Util.animateTimeout @SIDE_BY_SIDE_SPLIT_DURATION + @SIDE_BY_SIDE_SLIDE_DURATION, =>
        # Finalize animation.
        jQuery.fx.off = originalJQueryFxOff
        @sideBySideAnimating = false
    else
      # callapse to unified diff
      @isSideBySide = false
      $("div.file").removeClass("sideBySide")
      $.cookies(@SIDE_BY_SIDE_COOKIE, "false")
      $("#sideBySideButton").text("View Side-By-Side")

      collapseCodeTablesIntoOne = =>
        # move right table to the middle, and make it width of rest of page
        rightCodeTable.animate({ "left": @numberColumnOuterWidth, "width" :
            @originalLeftWidth - @numberColumnOuterWidth }, @SIDE_BY_SIDE_SPLIT_DURATION)
        # expand left table to width of rest of the page
        leftCodeTable.animate({ "width" : @originalLeftWidth}, @SIDE_BY_SIDE_SPLIT_DURATION)

        container.animate {"width": @originalContainerWidth}, @SIDE_BY_SIDE_SPLIT_DURATION, =>
              # after the side-by-side callapse animation is done,
              #  reset everything to the way it should be for unified diff
              $(".codeLeft .added > .codeText").css("visibility", "visible")
              @setSideBySideCommentVisibility()
              $(".codeRight").hide()
              $(".codeLeft .rightNumber").show()
              jQuery.fx.off = originalJQueryFxOff
              @sideBySideAnimating = false
        # jQuery sets this to "hidden" while animating width. We don't want to hide our logo, which overflows.
        container.css("overflow", "visible")

      # Animate the diff lines; when we're done, animate collapsing both sides of the diff into one.
      # slide the extra lines out
      linesToCollapse = $(".diffLine[replace='true']")
      linesToCollapse.find(".slideDiv").slideDown(@SIDE_BY_SIDE_SLIDE_DURATION)
      linesToCollapse.slideDown(@SIDE_BY_SIDE_SLIDE_DURATION)
      # remove grey from extra lines (don't wait for the previous animation if there's nothing happening).
      Util.animateTimeout linesToCollapse.length && @SIDE_BY_SIDE_SLIDE_DURATION, =>
        rightCodeTable.find(".diffLine[tag='removed']").removeClass "spacingLine"
        leftCodeTable.find(".diffLine[tag='added']").removeClass "spacingLine"
        collapseCodeTablesIntoOne()

  # Set the correct visibility for comments in side-by-side.
  setSideBySideCommentVisibility: ->
    rightCodeTable = $(".codeRight")
    leftCodeTable = $(".codeLeft")
    if @isSideBySide
      leftCodeTable.find(".comment, .commentForm").css("visibility": "hidden")
      leftCodeTable.find(".removed").find(".comment, .commentForm").css("visibility", "visible")

      rightCodeTable.find(".comment, .commentForm").css("visibility", "visible")
      rightCodeTable.find(".removed").find(".comment, .commentForm").css("visibility", "hidden")
    else
      leftCodeTable.find(".comment, .commentForm").css("visibility", "visible")
      rightCodeTable.find(".comment, .commentForm").css("visibility", "hidden")

  toggleReviewRequest: (showRequest = null) ->
    return unless window.userLoggedIn
    reviewRequest = $("#reviewRequest")
    if (reviewRequest.attr("animatingDirection") == "in" && !showRequest?) || showRequest
      reviewRequest.show()
      reviewRequest.animate({ top: -20 }, 210, "easeOutBack")
      reviewRequest.attr("animatingDirection", "out")
      reviewRequest.find("#authorInput").focus()
    else
      reviewRequest.attr("animatingDirection", "in")
      reviewRequest.animate({ top: -100 }, 100, "linear", ->
        reviewRequest.find("#requestSubmitted").hide()
        reviewRequest.find("#requestInput").show()
        reviewRequest.find("#authorInput").blur()
        reviewRequest.hide()
      )
    false

  submitReviewRequest: (e) ->
    emails = $("#authorInput").val().replace(/,?\s*$/, "")
    return if emails == ""
    sha = $("#commit").attr("sha")
    $("#reviewRequest #requestInput").hide()
    $("#reviewRequest #authorInput").val("")
    $("#reviewRequest #requestSubmitted span").html(" " + emails)
    $("#reviewRequest #requestSubmitted").show()
    $.ajax
      type: "post"
      url: "/request_review"
      data: { sha: sha, emails: emails }
      complete: => Util.setTimeout 2000, => @toggleReviewRequest(false)

  # This is called when the user attempts to navigate away. Let's prompt them if there are any unsaved comment
  # boxes with content on the page.
  confirmNavigation: ->
    for textarea in $("textarea.commentText")
      unless $.trim(textarea.value) == ""
        return "You have an unsaved comment."

$(document).ready(-> Commit.init())
# This needs to happen on page load because we need the styles to be rendered.
$(window).load(-> Commit.calculateMarginSize())
$(window).bind "beforeunload", -> Commit.confirmNavigation()

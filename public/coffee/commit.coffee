# Main javascript for the diff page UI
#
# Note: when modifying or removing rows from table of code lines, use findTwinFromBothSides to make sure
#   the same modification is done to both sides of the side-by-side view.
#   When adding a new row, similarly, make sure to add it to both tables equally and set the diff-line-number
#   attribute to be the same for both sides so that its twin can be found.

window.Commit =
  SIDE_BY_SIDE_SLIDE_DURATION: 300
  SIDE_BY_SIDE_SPLIT_DURATION: 700
  SIDE_BY_SIDE_CODE_WIDTH: 830

  init: ->
    $(".addCommentButton").click (e) => @onAddCommentMouseAction e
    $("a.tipsyCommentCount").tipsy(gravity: "w")
    $(".diffLine").dblclick (e) => @onAddCommentMouseAction e
    $(".reply").live "click", (e) => @onAddCommentMouseAction e
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
    $("#hideCommentButton").live "click", (e) => @toggleComments()
    $(".diffCommentCount > a").live "click", (e) => @toggleSingleComment(e)
    $("#requestInput button").click (e) => @submitReviewRequest()
    $(".expandLink.all").click (e) => @expandContextAll(e)
    $(".expandLink.below").click (e) => @expandContext(e, 10, "below")
    $(".expandLink.above").click (e) => @expandContext(e, 10, "above")
    $("#commit .file").on("mouseenter", ".contextExpander", @expandContextHoverIn)
    $("#commit .file").on("mouseleave", ".contextExpander", @expandContextHoverOut)

    @currentlyScrollingTimer = null

    # Put the approval overlay message div on the page.
    $("body").append $(Snippets.approvalOverlay)
    approvalPopup = $(".approvalPopup.overlay .container")
    approvalPopup.on "blur", ->
      approvalPopup.empty()
      $(".approvalPopup.overlay").css("visibility", "hidden")
    KeyboardShortcuts.registerShortcut approvalPopup, "esc", ->
      approvalPopup.blur()
      false
    KeyboardShortcuts.registerShortcut approvalPopup, "a", ->
      approvalPopup.blur()
      $("#approveButton, #disapproveButton").click()
      false
    KeyboardShortcuts.createShortcutContext approvalPopup

    commitComment = $("#commitComments .commentText")
    KeyboardShortcuts.createShortcutContext commitComment
    KeyboardShortcuts.registerShortcut commitComment, "esc", => commitComment.blur()
    KeyboardShortcuts.registerShortcut commitComment, "ctrl+p", (e) =>
      $(e.target).parents(".commentForm").find(".commentPreview").click()
      # Prevent side effects such as cursor movement.
      false

    shortcuts =
      "h": => @toggleComments()
      "a": => @approveOrDisapprove()
      "j": => @selectNextLine true
      "k": => @selectNextLine false
      "shift+n": => @scrollFile true
      "shift+p": => @scrollFile false
      "e": => @showFullDiff()
      "n": => @scrollChunk true
      "p": => @scrollChunk false
      "b": => @toggleSideBySide true
      "r": => @toggleReviewRequest(true)
      "shift+c": =>
        commitComment.focus()
        false
      "return": =>
        $(".diffLine.selected .addCommentButton").first().dblclick() unless $(".commentCancel").length > 0
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

    @toggleSideBySide(false) if $("#commit").attr("data-default-to-side-by-side") == "true"

    # Review request author autocompletion
    $("#reviewRequest #authorInput").autocomplete
      source: (request, callback) ->
        substringMatch = $("#authorInput").val().match(/(^([^,]*)$|,\s*([^,]*)$)/)
        substring = substringMatch[2] || substringMatch[3]
        $.ajax
          type: "get"
          url: "/autocomplete/authors"
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

  pluralize: (count, singular, plural) ->
    text = if count == 1 then singular else (plural || "#{singular}s")
    "#{count} #{text}"

  calculateMarginSize: ->
    commit = $("#commit")
    # We need to add 1 to account for the extra 'diff' character (" ", "+", or "-")
    lineSize = parseInt(commit.attr("margin-size")) + 1
    maxLengthLine = ("a" for i in [1..lineSize]).join("")
    marginSizer = $(Snippets.marginSizer(maxLengthLine))
    commit.append(marginSizer)
    marginSize = marginSizer.width()
    marginSizer.remove()
    # Position the margin line and show it once it's in the right place.
    $("#commit .marginLine").css("left", "#{marginSize}px").css("opacity", 0.1)

  # Display a popup prompt when the user hits 'a' to confirm that they want to approve.
  approveOrDisapprove: ->
    if $("#approveButton").size() > 0
      choice = "approve"
    else if $("#disapproveButton").size() > 0
      choice = "disapprove"
    else
      return
    $(".approvalPopup.overlay").css("visibility", "visible")
    approvalPopup = $(".approvalPopup.overlay .container")
    approvalPopup.append $(Snippets.approvalPopup(choice))
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
    return if @currentlyScrollingTimer?
    $(".diffLine.selected").removeClass("selected")

  selectLine: (event) ->
    return if @currentlyScrollingTimer?
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
    for line in visibleLines
      if @lineVisible(line, "top")
        $(line).addClass("selected")
        break

  selectNextLine: (next = true) ->
    selectedLine = $(".diffLine.selected")
    visibleLines = $(".diffLine").filter(":visible")
    if @isSideBySide
      visibleLines = visibleLines.filter("[replace='false']")
    if selectedLine.length == 0 or not @lineVisible(selectedLine)
      @selectNextVisibleLine()
    else
      index = visibleLines.index(selectedLine[0])
      return if (not next and index == 0) or (next and index == (visibleLines.length - 1))
      selectedLine.removeClass("selected")
      newIndex = if next then index + 1 else index - 1
      $(visibleLines[newIndex]).addClass("selected")
    scroll = if next then "bottom" else "top"
    window.clearTimeout(@currentlyScrollingTimer) if @currentlyScrollingTimer?
    @currentlyScrollingTimer = Util.setTimeout 300, => @currentlyScrollingTimer = null
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

  expandContextHoverIn: (event) ->
    row = $(event.target).closest(".contextExpander")
    row.find(".expandEllipsisContainer").hide()
    row.find(".expandContainer").css("display", "inline-block")

  expandContextHoverOut: (event) ->
    row = $(event.target).closest(".contextExpander")
    row.find(".expandContainer").hide()
    row.find(".expandEllipsisContainer").css("display", "inline-block")

  # Expand all the context hidden when a user clicks "Show all"
  expandContextAll: (event) ->
    expander = $(event.currentTarget).closest(".contextExpander")
    prev = expander.prev()
    if prev.is(":visible")
      diffLines = expander.nextUntil(":visible")
    else
      diffLines = expander.prevUntil(":visible")
    @findTwinFromBothSides(diffLines).show()
    @findTwinFromBothSides(expander).remove()

  # Expand some number of lines either above or below the fold of the context expander
  expandContext: (event, count, direction) ->
    expander = $(event.currentTarget).closest(".contextExpander")
    if expander.is(".topExpander") and direction == "below"
      refreshLine = $(expander.nextAll(":visible")[0])
    if expander.prev().is(":visible")
      lineRange = expander.nextUntil(":visible")
    else
      lineRange = $(expander.prevUntil(":visible").toArray().reverse())
    [rangeToExpand, attachLines, attachDirection] = @getContextRangeToExpand(lineRange, count, direction)
    @findTwinFromBothSides(expander).remove()
    rangeToExpand.show()
    top = attachDirection == "above" && attachLines.first().prevAll(":visible").length == 0
    bottom = attachDirection == "below" && attachLines.first().nextAll(":visible").length == 0
    incremental = lineRange.length * 2 - rangeToExpand.length > 10 * 2
    @createContextExpander(attachLines, attachDirection, top, bottom, incremental, refreshLine ? null)

  # Context expander helper function
  #
  # Arguments:
  #  - range: All lines hidden by the context expander
  #  - count: Number of lines to reveal
  #  - direction: Direction in which to reveal lines ("above" or "below")
  #
  # Returns:
  #  - Set of lines to reveal
  #  - Lines to attach the new context expander to
  #  - Direction in which to attach the new context expander
  getContextRangeToExpand: (range, count, direction) ->
    if direction == "above"
      rangeToExpand = @findTwinFromBothSides(range.slice(0, count))
      # rangeToExpand.slice(-2) is equivalent to findTwinFromBothSides(rangeToExpand.last)
      attachLines = rangeToExpand.slice(-2)
      [rangeToExpand, attachLines, "below"]
    else
      rangeToExpand = @findTwinFromBothSides(range.slice(-count))
      attachLines = rangeToExpand.slice(0,2)
      [rangeToExpand, attachLines, "above"]

  # Given a jquery array of row elements from code table, return a jquery array of row elements from both
  # tables of the side by side view
  #
  # Arguments:
  #  - rowElements: jquery array of elements from a single side of side-by-side
  #
  # Returns:
  #  - jquery array of elements including the same rows from both sides of side-by-side
  findTwinFromBothSides: (rowElements) ->
    fileElement = rowElements.first().parents(".file")
    elementsFromBothSides = $.map rowElements, (x) ->
      lineNumber = $(x).attr("diff-line-number")
      fileElement.find("[diff-line-number='" + lineNumber + "']").toArray()
    $(elementsFromBothSides)

  # Make a call to the server to render a new context expander, attach it to the DOM, and register event
  # handlers
  # TODO(kle): no reason this can't be done both client and server side
  #
  # Arguments:
  #  - codeLines: diffline DOM elements to attach to
  #  - attachDirection: Indicates whether to append or prepend the context expander to the code line. Valid
  #       options: "above", "below"
  #  - top: Indicates whether or not this context expander will be the top-most visible element for this file
  #       in the diff view, which determines whether or not a border is needed. Valid options: (true, false)
  #  - bottom: Indicates whether or not this context expander will be the bottom-most visible element for
  #       this file in the diff view, which determines whether or not a border is needed.
  #       Valid options: (true, false)
  #  - incremental: Indicates whether or not to render the "Show 10 Above" and "Show 10 Below" options. If
  #       incremental is false, then only the "Show All" option will appear for this context expander.
  #       Valid options: (true, false)
  #  - refreshLine: Nasty hack to get around a rendering bug. Happens to topExpanders expanding below.
  createContextExpander: (codeLines, attachDirection, top, bottom, incremental, refreshLine) ->
    renderedExpander = Snippets.contextExpander(top, bottom, codeLines.attr("diff-line-number"), incremental)
    contextExpander = $(renderedExpander)
    contextExpander.find(".expandLink.all").click (e) => @expandContextAll(e)
    contextExpander.find(".expandLink.above").click (e) => @expandContext(e, 10, "above")
    contextExpander.find(".expandLink.below").click (e) => @expandContext(e, 10, "below")
    codeLines.before(contextExpander) if attachDirection == "above"
    codeLines.after(contextExpander) if attachDirection == "below"
    expander = if attachDirection == "above" then codeLines.prev() else codeLines.next()
    expander.find(".expandEllipsis").trigger("mouseenter")
    # NOTE(kle): rerender hack to get around disappearing diffline border (issue #197)
    refreshLine?.hide()
    refreshLine?.show(1)

  onAddCommentMouseAction: (e) ->
    $target = $(e.target)
    unless ($target.parents(".commentBody").size() > 0) ||
        e.target.tagName.toLowerCase() in ["input", "textarea"]
      window.getSelection().removeAllRanges()
    return unless $target.closest(".codeText,button.reply").size() > 0 || $target.hasClass("addCommentButton")
    # Don't show multiple comment boxes
    return if $target.parents(".diffLine").find(".commentForm").size() > 0
    return unless window.userLoggedIn

    if $(e.currentTarget).hasClass("diffLine")
      codeLine = $(e.currentTarget)
    else
      codeLine = $(e.currentTarget).parents(".diffLine")
    codeLines = @findTwinFromBothSides(codeLine)
    lineNumber = codeLine.attr "diff-line-number"
    # Select line and add form to both left and right tables (so that the length of them stay the same).
    filename = codeLines.parents(".file").attr("filename")
    sha = codeLines.parents("#commit").attr("sha")
    repoName = codeLines.parents("#commit").attr("repo")
    @createCommentForm(codeLines, repoName, sha, filename, lineNumber)

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
        comment = $(html)
        commentForm = comment.find(".commentForm")
        commentForm.click (e) -> e.stopPropagation()
        # Add a random id so matching comments on both sides of side-by-side can be shown.
        commentForm.attr("form-id", Math.floor(Math.random() * 10000))
        commentForm.find(".commentCancel").click (e) => @onCommentCancel(e)
        commentForm.find(".commentPreview").click @onCommentPreview
        codeLine.append(comment)
        @setSideBySideCommentVisibility()

        textarea = codeLine.find(".commentForm .commentText").filter(-> $(@).css("visibility") == "visible")
        KeyboardShortcuts.createShortcutContext textarea
        textarea.focus()
        textarea.mouseup (e) => @onCommentTextAreaResize(e)
        KeyboardShortcuts.registerShortcut textarea, "esc", => textarea.blur()
        KeyboardShortcuts.registerShortcut textarea, "ctrl+shift+p", (e) =>
          $(e.target).parents(".commentForm").find(".commentPreview").click()
          # Prevent side effects such as cursor movement.
          false

  #
  #  Ensure that when comment text areas resize, the resize affects both sides of side by side
  #
  onCommentTextAreaResize: (e) ->
    width = $(e.target).width()
    height = $(e.target).height()
    formId = $(e.target).parents(".commentForm").attr("form-id")
    formFromBothSides = $(e.target).parents(".file").find("[form-id='" + formId + "']")
    commentTextFromBothSides = formFromBothSides.find(".commentText")
    commentTextFromBothSides.width(width)
    commentTextFromBothSides.height(height)

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
      success: (html) => @onCommentSubmitSuccess(html, form, target)


  onCommentSubmitSuccess: (html, formElement, target) ->
    @updateCommentCount(target.parents(".diffLine"))
    form = $(formElement)
    comment = form.parents(".commentContainer")
    comment.before(html)
    if form.parents(".diffLine").size() > 0
      comment.remove()
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

  updateCommentCount: (diffLineElement) ->
    numComments = diffLineElement.find(".commentContainer").size()
    link = diffLineElement.find('a.tipsyCommentCount')
    $(link).children("span").text(numComments)
    $(link).attr("commentcount", numComments)
    $(link).attr("title", @pluralize(numComments, "comment"))

  onCommentCancel: (e) ->
    e.stopPropagation()
    # Make sure changes to form happen to both tables to maintain height.
    formId = $(e.currentTarget).parents(".commentForm").attr("form-id")
    form = $(e.currentTarget).parents(".file").find(".commentForm[form-id='" + formId + "']")
    form.parents(".commentContainer.").remove()
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
        diffLine = target.parents(".diffLine")
        file = target.parents(".file")
        if file.size() > 0
          form = file.find(".comment[commentid='" + commentId + "']")
        else
          form = target.parents(".comment")
        form.parents(".commentContainer").remove()
        @setSideBySideCommentVisibility()
        @updateCommentCount(diffLine)

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

  showFullDiff: ->
    $(".diffLine").show()
    $(".contextExpander").remove()

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
      # push the comment count bubbles out
      $('.diffCommentCount').css("left", newCodeWidth * 2 + 4)

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
        # unset the absolute position of the comment count bubbles.
        $('.diffCommentCount').css("left", "")

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
      leftCodeTable.find(".commentContainer, .commentForm").css("visibility": "hidden")
      leftCodeTable.find(".removed").find(".commentContainer, .commentForm").css("visibility", "visible")

      rightCodeTable.find(".commentContainer, .commentForm").css("visibility", "visible")
      rightCodeTable.find(".removed").find(".commentContainer, .commentForm").css("visibility", "hidden")

    else
      leftCodeTable.find(".commentContainer, .commentForm").css("visibility", "visible")
      rightCodeTable.find(".commentContainer, .commentForm").css("visibility", "hidden")

  toggleSingleComment: (event) ->
    target = $(event.target)
    target.parent("a").hide()
    target.parent("a").tipsy("hide")
    comments = target.parents(".code").find(".commentContainer")
    comments.show()

    if ($(".diffCommentCount > a:visible").size() == 0)
      @commentsHidden = false
      $("#hideCommentButton").text("Hide Comments")


  toggleComments:  ->
    if (@commentsHidden)
      @commentsHidden = false
      $("#hideCommentButton").text("Hide Comments")
      $(".commentContainer").has(".comment").show()
      $(".diffCommentCount > a").hide()
    else
      @commentsHidden = true
      $("#hideCommentButton").text("Show Comments")
      # only hide comments for files, not commit comments at the bottom of the page.
      $(".file .commentContainer").has(".comment").hide()
      $('.diffCommentCount > a[commentCount != "0"]').show()

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

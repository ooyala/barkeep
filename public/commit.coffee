# import common.coffee, jquery, and jquery-json

window.Commit =
  init: ->
    $(document).keydown (e) => @onKeydown e
    $(".diffLine").click(Commit.onDiffLineClick)
    $(".commentForm").live "submit", (e) => @onCommentSubmit e
    $("#approveButton").live "click", (e) => @onApproveClicked e
    $("#disapproveButton").live "click", (e) => @onDisapproveClicked e
    $(".delete").live "click", (e) => @onCommentDelete e

  onKeydown: (event) ->
    return unless KeyboardShortcuts.beforeKeydown(event)
    switch KeyboardShortcuts.keyCombo(event)
      when "j"
        window.scrollBy(0, Constants.SCROLL_DISTANCE_PIXELS)
      when "k"
        window.scrollBy(0, Constants.SCROLL_DISTANCE_PIXELS * -1)
      when "n"
        @scrollFile(true)
      when "p"
        @scrollFile(false)
      else
        KeyboardShortcuts.globalOnKeydown(event)

  scrollFile: (next = true) ->
    previousPosition = 0
    for file in $("#commit .file")
      currentPosition = $(file).offset().top
      if currentPosition < $(window).scrollTop() or ((currentPosition == $(window).scrollTop()) and next)
        previousPosition = currentPosition
      else
        break
    window.scroll(0, if next then currentPosition else previousPosition)

  #Logic to add comments
  onDiffLineClick: (e) ->
    codeLine = $(e.currentTarget).find(".code")
    lineNumber = codeLine.parents(".diffLine").attr("diff-line-number")
    filename = codeLine.parents(".file").attr("filename")
    sha = codeLine.parents("#commit").attr("sha")
    Commit.createCommentForm(codeLine, sha, filename, lineNumber)

  createCommentForm: (codeLine, commitSha, filename, lineNumber) ->
    $.ajax({
      type: "get",
      url: "/comment_form",
      data: {
        sha: commitSha,
        filename: filename,
        line_number: lineNumber
      },
      success: (html) ->
        commentForm = $(html)
        commentForm.click (e) -> e.stopPropagation()
        commentForm.find(".commentText").keydown (e) -> e.stopPropagation()
        codeLine.append(commentForm)
        commentForm.find(".commentText").focus();
    })

  onCommentSubmit: (e) ->
    e.preventDefault()
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
      data: { commit_sha: $("#commit").attr("sha") }
      success: (bannerHtml) ->
        $("#approveButton").replaceWith(bannerHtml)
    })

  onDisapproveClicked: (e) ->
    $.ajax({
      type: "post",
      url: "/disapprove_commit",
      data: { commit_sha: $("#commit").attr("sha") }
      success: ->
        $("#approvedBanner").replaceWith("<button id='approveButton' class='fancy'>Approve Commit</button>")
    })

$(document).ready(-> Commit.init())

# import common.coffee, jquery, and jquery-json

window.Commit =
  init: ->
    $(document).keydown (e) => @onKeydown e
    $(".diffLine").click(Commit.onDiffLineClick)

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
        commentForm.submit Commit.onCommentSubmit
        commentForm.find(".commentCancel").click Commit.onCommentCancel
        codeLine.append(commentForm)
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
    $(form).after(html)
    $(form).remove()

  onCommentCancel: (e) ->
    e.stopPropagation()
    $(e.currentTarget).parents(".commentForm").remove()

$(document).ready(-> Commit.init())

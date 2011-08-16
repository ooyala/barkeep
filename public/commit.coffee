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
    codeLine.append(Commit.createCommentForm(sha,filename,lineNumber))

  createCommentForm: (commitSha, filename, lineNumber)->
    commentForm = $(" <form class='commentForm' action='/comment' type='POST'>
                          <div class='heading'>Add a comment</div>
                          <input type='hidden' name='sha' value='#{commitSha}'/>
                          <input type='hidden' name='filename' value='#{filename}' />
                          <input type='hidden' name='line_number' value='#{lineNumber}' />
                          <div class='body'>
                            <textarea class='commentText' name='text'></textarea>
                          </div>
                          <div class='commentControls'>
                            <input class='commentSubmit' type='submit' value='Submit' />
                            <input class='commentCancel' type='button' value='Cancel' />
                          </div>
                      </form>")
    commentForm.click (e) -> e.stopPropagation()
    commentForm.find(".commentText").keydown (e) -> e.stopPropagation()
    commentForm.submit Commit.onCommentSubmit
    commentForm.find(".commentCancel").click Commit.onCommentCancel
    return commentForm

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

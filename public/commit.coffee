# import common.coffee, jquery, and jquery-json

window.Commit =
  init: ->
    $(document).keydown (e) => @onKeydown e
    $(".diffLine").click(Commit.onDiffLineClick)

  onKeydown: (event) ->
    event.stopPropagation()
    switch event.which
      when Constants.KEY_J
        window.scrollBy(0, Constants.SCROLL_DISTANCE_PIXELS)
      when Constants.KEY_K
        window.scrollBy(0, Constants.SCROLL_DISTANCE_PIXELS * -1)
      when Constants.KEY_N
        @scrollFile(true)
      when Constants.KEY_P
        @scrollFile(false)

  scrollFile: (next = true) ->
    previousPosition = 0
    for file in $("#commit .file")
      currentPosition = $(file).offset().top
      if currentPosition < $(window).scrollTop() or ((currentPosition == $(window).scrollTop()) and next)
        previousPosition = currentPosition
      else
        break
    window.scroll(0, if next then currentPosition else previousPosition)

  #Support to add comments

  onDiffLineClick: (e) ->
    $(e.currentTarget).after(Commit.createCommentForm('foo','bar','hi'))

  createCommentForm: (commitSha, filename, lineNumber)->
    commentForm = $(" <form class='commentForm' action='/comment' type='POST'>
                          Comment: <input class='text' type='text' name='commentText' />
                          <input type='hidden' name='sha' value='#{commitSha}'/>
                          <input type='hidden' name='filename' value='#{filename}' />
                          <input type='hidden' name='line_number' value='#{lineNumber}' />
                          <input class='commentSubmit' type='submit' value='Submit' />
                          <input class='commentCancel' type='button' value='Cancel' />
                      </form>")
    commentForm.children(".commentText").keydown (e) -> e.stopPropagation()
    commentForm.submit Commit.onCommentSubmit
    commentForm.children(".commentCancel").click Commit.onCommentCancel
    return commentForm

  onCommentSubmit: (e) ->
    e.preventDefault()
    data = {}
    $(e.currentTarget).children("input").each (i,e) -> data[e.name] = e.value if e.name
    $.ajax
      type:e.currentTarget.type,
      data: data,
      url: e.currentTarget.action,
      success: (html) -> Commit.onCommentCancel(html, e.currentTarget)

  onCommentSubmitSuccess: (html, form) ->
    $(form).after(html)
    $(form).remove()

  onCommentCancel: (e) ->
    $(e.currentTarget).parent(".commentForm").remove()

$(document).ready(-> Commit.init())

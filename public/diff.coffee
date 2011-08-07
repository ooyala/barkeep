# import common.coffee, jquery, jquery UI, and jquery-json

window.Diff =
  init:


  createCommentForm: (container, commitSha, filename, lineNumber)->
    commentForm = $(" <form class='commentForm' id='commentForm_#{commitSha}_#{filename}_#{lineNumber}'
                            action='/comment' >
                          Comment: <textarea class='commentText' name='commentText'></textarea>
                          <input class='commentSubmit' type='button' value='Submit' />
                          <input class='commentCancel' type='button' value='Cancel' />
                      </form>")
    container.append(commentForm)
    commentForm.children(".commentSubmit").click(onCommentSubmit)
    commentForm.children(".commentCancel").click(onCommentCancel)

  onCommentSubmit: (button) ->
    #submitComment(button.parent().children(".commentText").value)

  onCommentCancel: (button) ->


$(document).ready(-> Diff.init())

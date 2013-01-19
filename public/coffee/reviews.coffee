
window.Reviews =
  init: ->
    $(".review .delete").live "click", (e) => @onReviewComplete e

  onReviewComplete: (e) ->
    target = $(e.currentTarget)
    repo = target.data("repo")
    sha = target.data("sha")
    $.ajax({
      type: "post",
      url: "/complete_review_request",
      data: {
        repo_name: repo
        commit_sha: sha
      }
      success: =>
        row = target.parents(".reviewRequestRow").detach()
        $("#recentlyReviewed > tbody").prepend(row)
    })
    false

$(document).ready(-> Reviews.init())

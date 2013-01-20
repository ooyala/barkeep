
window.Reviews =
  init: ->
    $(".review .delete").live "click", (e) => @onReviewComplete e
    $("#reviewLists").sortable
      placeholder: "savedSearchPlaceholder"
      handle: ".dragHandle"
      axis: "y"
      start: =>
        $.fn.tipsy.disable()
      stop: =>
        $.fn.tipsy.enable()
        @reorderReviewLists()

  reorderReviewLists: ->
    state = for reviewList in $("#reviewLists .review")
      $(reviewList).data("list-id")
    $.ajax
      type: "POST"
      url: "/review_lists/reorder"
      data: state.toString()

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
        $("#recent_reviewsTable > tbody").prepend(row)
    })
    false

$(document).ready(-> Reviews.init())

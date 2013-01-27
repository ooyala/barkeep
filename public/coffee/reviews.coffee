
window.Reviews =
  init: ->
    $(".review .deleteRequestRow").live "click", (e) => @onReviewComplete e
    $(".review .deleteCommentRow").live "click", (e) => @onCommentComplete e
    $(".review .expandCollapseListIcon").click (e) => @onExpandCollapseList e
    $(".review .showOverflowComments").click (e) => @onExpandCommentsList e
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
      reviewList.id
    $.ajax
      type: "POST"
      url: "/review_lists/reorder"
      data: state.toString()

  onExpandCommentsList: (e) ->
    target = $(e.currentTarget)
    target.parents(".commentEntryRow").find(".overflowCommentRow").show()
    target.parents(".overflowButtonRow").hide()
    false

  onExpandCollapseList: (e) ->
    target = $(e.currentTarget)
    if target.html() == "+"
      target.html("-")
    else
      target.html("+")
    target.parents(".review").find(".reviewListBody").toggleClass("collapsedList")
    false

  onCommentComplete: (e) ->
    target = $(e.currentTarget)
    commentId = target.data("commentId")
    $.ajax({
      type: "post",
      url: "/close_comment",
      data: {
        comment_id: commentId
      }
      success: (html) =>
        target.parents(".commentRow").remove()
        # TODO(jack): if no more comments, then remove commit line too
    })
    false

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
      success: (html) =>
        target.parents(".reviewRequestRow").remove()
        if $("#uncompleted_reviewsTable > tbody tr").length == 0
          $("#uncompleted_reviewsTable").hide()
          $("#uncompleted_reviews .noResults").show()
        $("#recent_reviews").html(html)
    })
    false

$(document).ready(-> Reviews.init())

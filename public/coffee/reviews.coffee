
window.Reviews =
  init: ->
    $(".review .deleteRequestRow").live "click", (e) => @onReviewComplete e
    $(".review .deleteCommentRow").live "click", (e) => @onCommentComplete e
    $(".review .expandCollapseListIcon").live "click", (e) => @onExpandCollapseList e
    $(".review .showOverflowComments").live "click", (e) => @onExpandCommentsList e
    $(".review .pageLeftButton").live "click", (e) => @showNextPage e, "prev"
    $(".review .pageRightButton").live "click", (e) => @showNextPage e, "next"
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
    target.parents(".commentEntryRow").find(".commentHidden").show()
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
    expanded = (target.parents(".commentEntryRow").find(".overflowCommentRow").css("display") != "none")
    $.ajax({
      type: "post",
      url: "/close_comment",
      data: {
        comment_id: commentId
        expand_comments: expanded
      }
      success: (html) =>
        if html.length == 0
          target.parents(".commentEntryRow").remove()
        else
          target.parents(".commentEntryRow").replaceWith(html)
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

  # Shows the next or previous page
  showNextPage: (e, direction) ->
    return if @fetching
    @fetching = true
    animationComplete = false
    fetchedHtml = null
    target = $(e.currentTarget)
    token = target.parents(".pageControls").data("token")
    reviewList = target.parents(".review")
    name = reviewList.attr("id")
    tableElement = reviewList.find(".commitsList")

    # We're going to animate sliding the current page away, while at the same time fetching the new page.
    # When both of those events are done, showFetchedPage can then be called.
    showFetchedPage = =>
      return unless animationComplete and fetchedHtml
      @fetching = false
      newReviewList = $(fetchedHtml)
      newReviewList.find(".commitsList").css("opacity", 0)
      reviewList.replaceWith newReviewList
      newReviewList.find(".commitsList").animate({ "opacity": 1 }, { duration: 150 })

    animateTo = (if direction == "next" then -1 else 1) * tableElement.width()
    tableElement.animate { "margin-left": animateTo },
      duration: 400,
      complete: =>
        animationComplete = true
        showFetchedPage()

    $.ajax
      url: "/review_list/#{name}",
      data: { token: token, direction: direction },
      success: (html) =>
        fetchedHtml = html
        showFetchedPage()

$(document).ready(-> Reviews.init())

# import common.coffee, jquery

window.Commit =
  init: ->
    $(document).keydown (e) => @onKeydown e

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

$(document).ready(-> Commit.init())

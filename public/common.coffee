# A more sane ordering of arguments for setTimeout.
window.timeout = (milliseconds, callback) -> setTimeout callback, milliseconds

window.Constants =
  KEY_CODES:
    13  : "return"
    27  : "escape"
    66  : "b"
    67  : "c"
    69  : "e"
    72  : "h"
    73  : "i"
    74  : "j"
    75  : "k"
    76  : "l"
    77  : "m"
    78  : "n"
    79  : "o"
    80  : "p"
    83  : "s"
    191 : "/"
    219 : "["
    221 : "]"

    # This is for keypress, not keydown. FF (on Mac only?) doesn't give any keycodes when you press shift-/.
    63  : "?"

  CONTEXT_BUFFER_PIXELS  : 100
  SCROLL_DISTANCE_PIXELS : 60 # Copied this setting from vimium

window.ShortcutOverlay =
  init: ->
    $.ajax
      url: "/keyboard_shortcuts#{location.pathname}"
      success: (html) =>
        $("#overlay").html html
        $("#overlay #shortcuts .close a").click (e) => @hide()

  show: ->
    @showing = true
    $("#overlay").css("visibility", "visible")

  hide: ->
    @showing = false
    $("#overlay").css("visibility", "hidden")

$(document).ready(-> ShortcutOverlay.init())

window.KeyboardShortcuts =
  # Translate a keydown event (or similar) to a nice string (e.g. control-alt-c => "ac_c")
  keyCombo: (event) ->
    modifiers = (m[0] for m in ["altKey", "ctrlKey", "metaKey", "shiftKey"] when event[m])
    modifier_string = modifiers.join("")
    modifier_string += "_" unless modifier_string == ""
    modifier_string + Constants.KEY_CODES[event.which]

  # Call before handling an event. The return value of this indicates whether to continue handling.
  beforeKeydown: (event) ->
    event.stopPropagation()
    if ShortcutOverlay.showing
      ShortcutOverlay.hide()
      return false
    true

  globalOnKeydown: (event) ->
    return if $.inArray(event.target.tagName, ["BODY", "HTML"]) == -1
    @beforeKeydown(event)
    switch @keyCombo(event)
      when "c"
        window.location.href = "/commits"
      when "s"
        window.location.href = "/stats"
      when "i"
        window.location.href = "/inspire"

  # This is a hack to get around the fact that it's not possible to detect a ? being pressed using the keydown
  # event in Firefox. This is the only shortcut for which we use this event.
  globalQuestionPress: (event) ->
    return if $.inArray(event.target.tagName, ["BODY", "HTML"]) == -1
    @beforeKeydown(event)
    switch @keyCombo(event)
      when "s_?"
        ShortcutOverlay.show()

$(document).keydown (e) => KeyboardShortcuts.globalOnKeydown e
$(document).keypress (e) => KeyboardShortcuts.globalQuestionPress e

window.Login =
  init: ->
    $(".logoutLink").click Login.logout

  logout: ->
    # need to logout from google too, but there is no way to get back, so do it in an iframe
    $("#logoutIFrame").load -> location.href = "/logout"
    $("#logoutIFrame").get(0).src = "https://www.google.com/accounts/Logout"
    return false

# Keep some amount of context on-screen to pad the selection position
window.ScrollWithContext = (selector, scroll="all") ->
  selection = $(selector)
  return unless selection.size() > 0
  selectionTop = selection.offset().top
  selectionBottom = selectionTop + selection.height()
  windowTop = $(window).scrollTop()
  windowBottom = windowTop + $(window).height()
  # If the selection if off-screen, center on it
  if selectionBottom < windowTop or selectionTop > windowBottom
    window.scroll(0, (selectionTop + selectionBottom) / 2 - $(window).height() / 2)
  # Otherwise ensure there is enough buffer
  else if (selectionTop - windowTop < Constants.CONTEXT_BUFFER_PIXELS) and
      (scroll == "all" or scroll == "top")
    window.scroll(0, selectionTop - Constants.CONTEXT_BUFFER_PIXELS)
  else if windowBottom - selectionBottom < Constants.CONTEXT_BUFFER_PIXELS and
      (scroll == "all" or scroll == "bottom")
    window.scroll(0, selectionBottom + Constants.CONTEXT_BUFFER_PIXELS - $(window).height())

$(document).ready(-> Login.init())

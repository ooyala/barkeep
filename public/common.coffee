# A more sane ordering of arguments for setTimeout.
window.timeout = (milliseconds, callback) -> setTimeout callback, milliseconds

window.Constants =
  KEY_CODES:
    13  : "return"
    27  : "escape"
    67  : "c"
    69  : "e"
    72  : "h"
    73  : "i"
    74  : "j"
    75  : "k"
    76  : "l"
    77  : "m"
    78  : "n"
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
    document.cookie = "email=; expires=Thu, 01-Jan-70 00:00:01 GMT;"
    #need to logout from google too, but there is no way to get back, so do it in an iframe
    $("#logoutIFrame").ready ->
      location.reload(true)
    logoutIFrame.location = 'https://www.google.com/accounts/Logout'
    return false

$(document).ready(-> Login.init())

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
    82  : "r"
    83  : "s"
    191 : "/"
    219 : "["
    221 : "]"

    # This is for keypress, not keydown. FF (on Mac only?) doesn't give any keycodes when you press shift-/.
    63  : "?"

  CONTEXT_BUFFER_PIXELS  : 100
  SCROLL_DISTANCE_PIXELS : 60 # Copied this setting from vimium

# TODO(caleb): Remove in subsequent commit.
# some utlility functions for reading/writing cookies and string manipulation
window.createCookie = (name, value, expires) ->
  document.cookie = name + "=" + value + "; expires=" + expires + "; path=/"

window.readCookie = (name) ->
  nameEq = name + "="
  for pair in document.cookie.split(';')
    trimmedPair = pair.ltrim()
    return trimmedPair.substring(nameEq.length) if trimmedPair.startsWith(nameEq)
  null

String.prototype.trim = () ->
  this.replace(/^\s+|\s+$/g,"")

String.prototype.ltrim = () ->
  this.replace(/^\s+/,"")

String.prototype.rtrim = () ->
  this.replace(/\s+$/,"")

String.prototype.startsWith = (s) ->
  this.indexOf(s) == 0

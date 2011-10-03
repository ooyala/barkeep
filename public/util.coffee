# Some common utility functions
window.Util =
  # A more sane ordering of arguments for setTimeout.
  timeout: (milliseconds, callback) -> setTimeout callback, milliseconds

  # A timeout that doesn't delay if jQuery.fx.off == true
  animateTimeout: (milliseconds, callback) ->
    if jQuery.fx.off
      callback()
    else
      @timeout milliseconds, callback

  # Keep some amount of context on-screen to pad the selection position
  scrollWithContext: (selector, scroll="all") ->
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

window.CommentForm =
  # Generates comment form html. This handles adding and editing comments
  create: (inline, edit, hiddenFields) ->
    className = if edit then "commentEditForm" else "commentForm"
    submitValue = if edit then "Save Edit" else "Post Comment"
    header = if edit then "" else """
      <div class='heading'><span class='addAComment'>Add a comment</span></div>
      <input type='hidden' name='repo_name' value='#{hiddenFields.repoName}' />
      <input type='hidden' name='sha' value='#{hiddenFields.sha}' />
      <input type='hidden' name='filename' value='#{hiddenFields.filename}' />
      <input type='hidden' name='line_number' value='#{hiddenFields.lineNumber}' />
    """
    """
      <form class='#{className}' action='/comment' type='POST'>
        #{header}
        <textarea class='commentText' name='text'></textarea>
        <div class='commentControls'>
          <input class='commentSubmit' type='submit' value='#{submitValue}' />
          #{if inline then "<input class='commentCancel' type='button' value='Cancel' />"}
        </div>
      </form>"
    """

window.ShortcutOverlay =
  init: ->
    $.ajax
      url: "/keyboard_shortcuts#{location.pathname}"
      success: (html) =>
        $("#overlay").html html
        $("#overlay .container").focus -> $("#overlay").css("visibility", "visible")
        $("#overlay .container").blur -> $("#overlay").css("visibility", "hidden")

        # Set up the keyboard shortcuts
        KeyboardShortcuts.createShortcutContext $("#overlay .container")
        KeyboardShortcuts.registerPageShortcut "shift+/", -> $("#overlay .container").focus()
        KeyboardShortcuts.registerShortcut $("#overlay .container"), "esc", ->
          $("#overlay .container").blur()
        $("#overlay .shortcuts .close a").click (e) -> $("#overlay .container").blur()

window.KeyboardShortcuts =
  init: ->
    @suspended = false
    @registerGlobals()

  # Register some shortcut on a page element.
  # element - some jquery element
  # shortcut - the jquery.hotkeys-formatted shortcut string
  # callback - the associated callback
  registerShortcut: (element, shortcut, callback) ->
    # Dumb special-casing we have to do for FF on Mac, because it doesn't give any keycodes when you press
    # shift-/ (question mark).
    if shortcut == "shift+/"
      element.keypress (e) =>
        return unless e.which == 63
        return if @suspended and not $(e.target).is(element)
        return if not $(e.target).is(element) and e.target.type == "text"
        callback.call(e)
      return
    element.bind "keydown", shortcut, (e) =>
      return if @suspended and not $(e.target).is(element)
      callback.call(e)

  registerPageShortcut: (shortcut, callback) -> @registerShortcut($(document), shortcut, callback)

  # A convenience function for specifying that an element is its own "shortcut context", which means that when
  # it is focused, page and global keyboard shortcuts will not apply.
  #
  # element - jquery element
  createShortcutContext: (element) ->
    # Make blur be fired for non-input elements. This terrible, wonderful hack courtesy of
    # http://www.barryvan.com.au/2009/01/onfocus-and-onblur-for-divs-in-fx/
    unless element.attr("tabindex")?
      element.attr("tabindex", -1)
      element.addClass "noFocusOutline"
    element.focus =>
      @suspended = true
      true
    element.blur =>
      @suspended = false
      true

  registerGlobals: ->
    @registerPageShortcut "c", -> window.location.href = "/commits"
    @registerPageShortcut "s", -> window.location.href = "/stats"
    @registerPageShortcut "i", -> window.location.href = "/inspire"

window.Login =
  init: ->
    $(".logoutLink").click Login.logout

  logout: ->
    # need to logout from google too, but there is no way to get back, so do it in an iframe
    $("#logoutIFrame").load -> location.href = "/logout"
    $("#logoutIFrame").get(0).src = "https://www.google.com/accounts/Logout"
    return false

$(document).ready ->
  ShortcutOverlay.init()
  Login.init()
  KeyboardShortcuts.init()

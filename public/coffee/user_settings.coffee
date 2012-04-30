window.Settings =
  init: ->
    $("#editDisplayName").on "click", (e) => @makeTextEditable(e)
    $("#lineLengthSlider").slider
      value: parseInt($("#lineLengthSlider").attr("data-value"))
      min: 80
      max: 150
      step: 5
      slide: (event, ui) -> $("#lineLength").text("#{ui.value} characters")
      stop: (event, ui) => @saveLineLength(event, ui)
    $("input[name='diffView']").on "change", (e) ->
      Util.saveUserPreference "default_to_side_by_side", $(e.target).val(), ->

  makeTextEditable: (event) ->
    $displayText = $(event.target)
    $inputText = $("<input type='text'></input>")
    $inputText.val($displayText.text().replace(/^\s+|\s+$/g, ""))
    $displayText.after($inputText)
    $displayText.hide()
    $inputText.focus()
    $inputText.on "blur", => @cancelTextEdit($inputText)
    KeyboardShortcuts.registerShortcut $inputText, "esc", => @cancelTextEdit($inputText)
    KeyboardShortcuts.registerShortcut $inputText, "return", => @saveTextEdit($inputText)

  saveLineLength: (event, ui) ->
    length = ui.value
    $("#lineLength").css { opacity: "0.5" }
    Util.saveUserPreference "line_length", length, -> $("#lineLength").css { opacity: "1.0" }

  cancelTextEdit: ($inputText) ->
    $inputText.siblings("span").show()
    $inputText.remove()

  saveTextEdit: ($inputText) ->
    value = $inputText.val()
    $displayText = $inputText.siblings("span")
    preference = $displayText[0].id.replace(/^edit/, "").toLowerCase()
    $displayText.text(value)
    $inputText.remove()
    $displayText.css { opacity: "0.5" }
    $displayText.show()
    Util.saveUserPreference preference, value, =>
      $displayText.css { opacity: "1.0" }

$(document).ready -> Settings.init()

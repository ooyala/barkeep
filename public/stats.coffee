
window.Stats =
  init: ->
    @loadStatValues()
    @graphPie()

  loadStatValues: ->
    @unreviewedPercent = parseFloat $("[name=unreviewedPercent]").val()
    @commentedPercent = parseFloat $("[name=commentedPercent]").val()
    @approvedPercent = parseFloat $("[name=approvedPercent]").val()

  graphPie: ->
    $.plot($("#pieGraph"), [
      { label: "Unreviewed", data: @unreviewedPercent, color: "#DD7467" },
      { label: "Commented", data: @commentedPercent, color: "#F2E952" },
      { label: "LGTM", data: @approvedPercent, color: "#1FBF36" }
    ], {
      series: {
        pie: {
          show: true
        }
      }
    })

$(document).ready(-> Stats.init())

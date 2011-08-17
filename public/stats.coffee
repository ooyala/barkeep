
window.Stats =
  init: ->
    @graphReviewPercent()

  graphReviewPercent: ->
    unreviewedPercent = parseFloat $("#reviewPercentGraph").attr("unreviewedPercent")
    commentedPercent = parseFloat $("#reviewPercentGraph").attr("commentedPercent")
    approvedPercent = parseFloat $("#reviewPercentGraph").attr("approvedPercent")
    $.plot($("#reviewPercentGraph"), [
      { label: "Unreviewed", data: unreviewedPercent, color: "#DD7467" },
      { label: "Commented", data: commentedPercent, color: "#67B6DD" },
      { label: "LGTM", data: approvedPercent, color: "#1FBF36" }
    ], {
      series: {
        pie: {
          show: true,
          radius: 1
          label: {
            show: true,
            radius: 0.75
            formatter: (label, series) ->
              '<div style="color: white; font-size: 0.8em; text-align: center; font-weight: bold">' +
                  label + '<br />' + Math.round(series.percent) + '%</div'
          }
        }
      },
      legend: {
        show: false
      }
    })

$(document).ready(-> Stats.init())

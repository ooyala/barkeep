window.Repos =
  init: ->
    $("button#clone").click =>
      repoUrl = $("#newRepoUrl").val()
      repoName = $("#newRepoName").val()
      $.ajax
        type: "post"
        url: "/admin/repos/create_new_repo"
        data: { url: repoUrl, name: repoName }
        dataType: "json"
        success: => @showConfirmationMessage("#{repoUrl} has been scheduled to be cloned as #{repoName}.")
        error: (response) => @showConfirmationMessage(response.responseText)

    $("#newRepoUrl").bind "propertychange keyup input paste", =>
      repoUrl = $("#newRepoUrl").val()
      match = /.*(?:\/|:)([^/:]+)\/*$/.exec repoUrl
      if match
        name = match[1]
        name = (/\s*([^\s]+)/.exec name)[1]
        suffix_match = /(.*)\.git$/.exec name
        if suffix_match
          name = suffix_match[1]
        $("#newRepoName").val(name)

    $(".trash").click (e) =>
      repoRow = $(e.target).closest("tr")
      repoName = repoRow.find("td:nth-of-type(1)").html()
      repoUrl = repoRow.find("td:nth-of-type(2)").html()
      if (confirm("Are you sure you want to delete this repository?\n\n#{repoName}\n#{repoUrl}"))
        $.ajax
          type: "post"
          url: "/admin/repos/delete_repo"
          data: { name: repoName }
          success: => @showConfirmationMessage("#{repoName} has been scheduled for deletion.")
          error: (response) => @showConfirmationMessage(response.responseText)

  showConfirmationMessage: (message) ->
    $("#confirmationMessage").show()
    $("#confirmationMessage").html(message)

$(document).ready -> Repos.init()

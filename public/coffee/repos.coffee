window.Repos =
  init: ->
    $("button#clone").click =>
      repoUrl = $("#newRepoUrl").val()
      $.ajax
        type: "post"
        url: "/admin/repos/create_new_repo"
        data: { url: repoUrl }
        dataType: "json"
        success: => @showConfirmationMessage("#{repoUrl} has been scheduled to be cloned.")
        error: (response) => @showConfirmationMessage(response.responseText)

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

$ -> Repos.init()

window.LdapSignin =
  init: ->
    KeyboardShortcuts.createShortcutContext($("#ldapSignin input"))

    $("#ldapSigninForm").submit (e) =>
      e.preventDefault()
      signinParams = { "provider_id": $("#ldapSignin #providerId").val(), "username": $("#ldapSignin #userName").val(), "password": $("#ldapSignin #password").val() }
      $.ajax({
        "type": "POST",
        url: "/signin/ldap_authenticate",
        data: signinParams,
        success: (e) ->
          window.location.replace(e)
        error: (jqXHR, textStatus, errorThrown) =>
          @showErrorMessage(if jqXHR.responseText? and $.trim(jqXHR.responseText).length > 0 then jqXHR.responseText else "Unknown error")
          console.log("error:")
          console.log(jqXHR)
          console.log(textStatus)
          console.log(errorThrown)
      })

  showErrorMessage: (message) ->
    $("#errorMessage").show()
    $("#errorMessage").html(message)

$(document).ready(-> LdapSignin.init())

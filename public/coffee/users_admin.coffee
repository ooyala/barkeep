window.UserAdmin =
  currentUserId: -> $("#manageUsers").attr("data-user-id")

  updatePermission: (userId, permission) ->
    $.ajax
      type: "POST",
      url: "/admin/users/update_permissions",
      data:
        user_id: userId,
        permission: permission

  confirmOwnDemotion: ->
    confirm("You are about to demote yourself! If you continue you will be redirected and unable " +
        "to view this page. Would you like to continue?")

  numberOfAdminUsers: -> $("input[type=radio][value=admin]:checked").size()

$ ->
  $("input[type=radio]").click ->
    targetUserId = $(event.target).attr("data-user-id")
    permission = $(event.target).val()

    # Prevent demoting the last admin.
    if UserAdmin.numberOfAdminUsers() == 0
      alert("Unable to demote the last admin user.")
      return false

    # Confirm user demoting themself.
    if UserAdmin.currentUserId() == targetUserId && !UserAdmin.confirmOwnDemotion()
      return false

    UserAdmin.updatePermission(targetUserId, permission)

    # Redirect a user if they demote themself.
    if UserAdmin.currentUserId() == targetUserId
      window.location = "/"

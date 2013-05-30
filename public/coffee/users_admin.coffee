window.UserAdmin =
  currentUserId: -> $("#manageUsers").attr("data-user-id")

  updatePermission: (userId, permission) ->
    $.ajax
      type: "POST",
      url: "/admin/users/update_permissions",
      data:
        user_id: userId,
        permission: permission

  deleteUser: (userId) ->
    $.ajax
      type: "DELETE"
      url: "/admin/users/#{userId}"
      success: -> $("tr[data-user-id=#{userId}]").fadeOut()

  confirmOwnDemotion: ->
    confirm("You are about to demote yourself! If you continue you will be redirected and unable " +
        "to view this page. Would you like to continue?")

  numberOfAdminUsers: -> $("input[type=radio][value=admin]:checked").size()

$(document).ready ->
  $("input[type=radio]").click (e) ->
    targetUserId = $(e.target).parents("tr").attr("data-user-id")
    permission = $(e.target).val()

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

  $(".trash").click (e) ->
    $row = $(e.target).parents("tr")
    userId = $row.attr("data-user-id")
    [name, email] = ($(td).text() for td in $row.find("td"))[0..1]
    return unless confirm("Are you sure you want to delete the user #{name} (#{email})?")
    UserAdmin.deleteUser(userId)

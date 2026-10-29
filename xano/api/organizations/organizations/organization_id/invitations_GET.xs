query "organizations/{organization_id}/invitations" verb=GET {
  api_group = "organizations"
  auth = "user"

  input {
    int organization_id
  }

  stack {
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $input.organization_id
        min_role       : "owner"
      }
    } as $ctx
  
    db.query invitations {
      where = $db.invitations.organization_id == $input.organization_id
      sort = {created_at: "desc"}
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "email"
        "role"
        "status"
        "expires_at"
        "invited_by"
        "accepted_by"
        "accepted_at"
      ]
    } as $invitations
  }

  response = $invitations
  guid = "_ludRVaglhwWY_zT-meB6KMtR5A"
}
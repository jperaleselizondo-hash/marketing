query "organizations/{organization_id}/members" verb=GET {
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
        min_role       : "viewer"
      }
    } as $ctx
  
    db.query organization_members {
      join = {
        user: {
          table: "user"
          where: $db.organization_members.user_id == $db.user.id
        }
      }
    
      where = $db.organization_members.organization_id == $input.organization_id
      sort = {created_at: "asc"}
      eval = {user_name: $db.user.name, user_email: $db.user.email}
      return = {type: "list"}
    } as $members
  }

  response = $members
  guid = "SEIv6F0whvfoiHxalfJA-89kSXc"
}
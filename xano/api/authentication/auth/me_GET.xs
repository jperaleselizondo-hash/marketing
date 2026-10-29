// Current user and their active organization memberships.
query "auth/me" verb=GET {
  api_group = "Authentication"
  auth = "user"

  input {
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $auth.id
      output = [
        "id"
        "created_at"
        "name"
        "email"
        "status"
        "is_platform_admin"
        "last_login_at"
      ]
    } as $user
  
    db.query organization_members {
      join = {
        organizations: {
          table: "organizations"
          where: $db.organization_members.organization_id == $db.organizations.id
        }
      }
    
      where = $db.organization_members.user_id == $auth.id && $db.organization_members.status == "active" && $db.organizations.status == "active"
      eval = {
        organization_name: $db.organizations.name
        organization_slug: $db.organizations.slug
      }
    
      return = {type: "list"}
    } as $memberships
  }

  response = {user: $user, memberships: $memberships}
  guid = "_ivw899nnAwVPoxcL4sdKJm8iZI"
}
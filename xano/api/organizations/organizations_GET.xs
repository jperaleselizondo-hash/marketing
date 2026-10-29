// Organizations the caller belongs to, with their role.
query organizations verb=GET {
  api_group = "organizations"
  auth = "user"

  input {
  }

  stack {
    db.query organization_members {
      join = {
        organizations: {
          table: "organizations"
          where: $db.organization_members.organization_id == $db.organizations.id
        }
      }
    
      where = $db.organization_members.user_id == $auth.id && $db.organization_members.status == "active"
      eval = {
        name      : $db.organizations.name
        slug      : $db.organizations.slug
        org_status: $db.organizations.status
      }
    
      return = {type: "list"}
    } as $organizations
  }

  response = $organizations
  guid = "Ga1IY9S9iNnrNGyAG0nQkWEr8xo"
}
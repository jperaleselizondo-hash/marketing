query "organizations/{organization_id}/brands" verb=GET {
  api_group = "catalog"
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
  
    db.query brands {
      where = $db.brands.organization_id == $input.organization_id
      sort = {name: "asc"}
      return = {type: "list"}
    } as $brands
  }

  response = $brands
  guid = "HKdg3agxMUTiz3JzHBCI5YS6axA"
}
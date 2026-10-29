query "organizations/{organization_id}" verb=GET {
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
  }

  response = {organization: $ctx.organization, role: $ctx.role}
  guid = "b0kDqbzm2aWVT9zDRk9oEU2LHv8"
}
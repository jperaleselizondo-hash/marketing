query "projects/{project_id}/capabilities" verb=GET {
  api_group = "product"
  auth = "user"

  input {
    int project_id
    enum? verification_status? {
      values = ["unverified", "verified", "disputed"]
    }
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "viewer"
      }
    } as $pc
  
    db.query product_capabilities {
      where = $db.product_capabilities.research_project_id == $input.project_id && $db.product_capabilities.verification_status ==? $input.verification_status
      sort = {created_at: "asc"}
      return = {type: "list"}
    } as $capabilities
  }

  response = $capabilities
  guid = "btvkYP1vHnKtESVTyhzSw6nZKhQ"
}
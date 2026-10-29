query "projects/{project_id}/capability-benefit-links" verb=GET {
  api_group = "product"
  auth = "user"

  input {
    int project_id
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "viewer"
      }
    } as $pc
  
    db.query capability_benefit_links {
      where = $db.capability_benefit_links.research_project_id == $input.project_id
      sort = {created_at: "asc"}
      return = {type: "list"}
    } as $links
  }

  response = $links
  guid = "qCvGUyIxoKnow7Qxnw0jWLkNIyU"
}
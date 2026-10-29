query "organizations/{organization_id}/projects" verb=GET {
  api_group = "research"
  auth = "user"

  input {
    int organization_id
    enum? status? {
      values = ["draft", "scoped", "collecting", "synthesizing", "archived"]
    }
  }

  stack {
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $input.organization_id
        min_role       : "viewer"
      }
    } as $ctx
  
    db.query research_projects {
      where = $db.research_projects.organization_id == $input.organization_id && $db.research_projects.deleted_at == null && $db.research_projects.status ==? $input.status
      sort = {created_at: "desc"}
      return = {type: "list"}
    } as $projects
  }

  response = $projects
  guid = "DYmUOGUZTQlsltvVIWrzDYkKRKs"
}
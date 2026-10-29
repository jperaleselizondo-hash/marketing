// Load a research project and authorize the caller through its organization.
// for_write additionally rejects archived projects.
function "research/project_context" {
  input {
    int user_id
    int project_id
    text min_role
    bool for_write?
  }

  stack {
    db.get research_projects {
      field_name = "id"
      field_value = $input.project_id
    } as $project
  
    precondition ($project != null && $project.deleted_at == null) {
      error_type = "notfound"
      error = "NOT_FOUND: Research project not found"
    }
  
    function.run "auth/org_context" {
      input = {
        user_id        : $input.user_id
        organization_id: $project.organization_id
        min_role       : $input.min_role
      }
    } as $ctx
  
    precondition ($input.for_write == false || $project.status != "archived") {
      error_type = "inputerror"
      error = "PROJECT_ARCHIVED: Archived projects are read-only"
    }
  }

  response = {project: $project, ctx: $ctx}
  guid = "CRtahfTQnPe0liLgb-GA7XWFCIk"
}
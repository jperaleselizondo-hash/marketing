// Increment a project's content_revision. Every write to project-scoped research data calls this,
// so a report generated at revision N is detectably stale once any evidence changes.
function "research/touch_project" {
  input {
    int project_id
  }

  stack {
    db.get research_projects {
      field_name = "id"
      field_value = $input.project_id
    } as $project
  
    var $next_revision {
      value = ($project.content_revision ?? 0) + 1
    }
  
    db.edit research_projects {
      field_name = "id"
      field_value = $input.project_id
      data = {content_revision: $next_revision, updated_at: now}
    }
  }

  response = $next_revision
  guid = "mjpQtd1--B7j4Til2uGkgnnlXEM"
}
query "reports/{report_id}" verb=GET {
  api_group = "workflow"
  auth = "user"

  input {
    int report_id
  }

  stack {
    db.get research_reports {
      field_name = "id"
      field_value = $input.report_id
    } as $report
  
    precondition ($report != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Report not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $report.research_project_id
        min_role  : "viewer"
      }
    } as $pc
  }

  response = {
    report    : $report
    is_current: $pc.project.current_report_id == $report.id
    is_stale  : $report.based_on_revision != $pc.project.content_revision
  }

  guid = "u09c3kuwsqwnz_2gODdgKDbwv84"
}
query "projects/{project_id}/reports" verb=GET {
  api_group = "workflow"
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
  
    db.query research_reports {
      where = $db.research_reports.research_project_id == $input.project_id
      sort = {version_no: "desc"}
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "version_no"
        "status"
        "schema_version"
        "report_json_hash"
        "source_manifest_hash"
        "based_on_revision"
        "methodology_version_id"
        "generated_job_id"
        "generated_by"
        "submitted_by"
        "submitted_at"
        "approved_by"
        "approved_at"
        "rejection_reason"
      ]
    } as $reports
  }

  response = {
    reports          : $reports
    current_report_id: $pc.project.current_report_id
    project_revision : $pc.project.content_revision
  }

  guid = "D61US_izdpp0HH4G0uy-AVxZY_c"
}
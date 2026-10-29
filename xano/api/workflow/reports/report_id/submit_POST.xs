// draft -> in_review. Refuses stale reports (evidence changed since generation) and reports with blocking issues.
query "reports/{report_id}/submit" verb=POST {
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
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ($report.status == "draft") {
      error_type = "inputerror"
      error = "INVALID_TRANSITION: Only draft reports can be submitted"
    }
  
    precondition ($report.based_on_revision == $pc.project.content_revision) {
      error_type = "inputerror"
      error = "STALE_REPORT: Evidence changed after this report was generated; generate a new version"
    }
  
    precondition ((($report.report_json.blocking_issues ?? [])|count) == 0) {
      error_type = "inputerror"
      error = "BLOCKING_ISSUES: Resolve the report's blocking issues first"
    }
  
    db.transaction {
      stack {
        db.edit research_reports {
          field_name = "id"
          field_value = $report.id
          data = {
            status          : "in_review"
            submitted_by    : $auth.id
            submitted_at    : now
            rejection_reason: null
            updated_at      : now
          }
        } as $updated
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $report.organization_id
            research_project_id: $report.research_project_id
            actor_id           : $auth.id
            entity_type        : "research_reports"
            entity_id          : $report.id
            action             : "submit"
            from_status        : "draft"
            to_status          : "in_review"
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "KezevDiO2qU5u0WMlIfvbYGNi9w"
}
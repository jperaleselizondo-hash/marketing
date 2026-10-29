// in_review -> draft with a reason. A rejected version can be resubmitted only if it is still current.
query "reports/{report_id}/reject" verb=POST {
  api_group = "workflow"
  auth = "user"

  input {
    int report_id
    text reason
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
        min_role  : "reviewer"
        for_write : true
      }
    } as $pc
  
    precondition ($report.status == "in_review") {
      error_type = "inputerror"
      error = "INVALID_TRANSITION: Only reports in review can be rejected"
    }
  
    precondition ((($input.reason|trim)|strlen) > 0) {
      error_type = "inputerror"
      error = "REASON_REQUIRED: Rejection needs a reason"
    }
  
    db.transaction {
      stack {
        db.edit research_reports {
          field_name = "id"
          field_value = $report.id
          data = {
            status          : "draft"
            rejection_reason: $input.reason
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
            action             : "reject"
            from_status        : "in_review"
            to_status          : "draft"
            reason             : $input.reason
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "9V4hhl7MwUdyZh1AsMvxrpo5-lg"
}
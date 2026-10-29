// Gate R5_REPORT. Atomic approval that freezes the report version.
// Concurrency: the transaction first updates the project row (taking its row lock) and only then re-reads the revision.
// Every evidence write bumps the same row via research/touch_project, so approval and edits serialize on that lock.
// Fails closed if the report is stale, its stored content no longer matches its hash, its sources changed,
// or it has blocking issues. Supersedes the previously approved version. Idempotent for already-approved reports.
query "reports/{report_id}/approve" verb=POST {
  api_group = "workflow"
  auth = "user"

  input {
    int report_id
    text? note?
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
  
    conditional {
      if ($report.status == "approved") {
        return {
          value = {report: $report, idempotent: true}
        }
      }
    }
  
    db.transaction {
      stack {
        db.edit research_projects {
          field_name = "id"
          field_value = $report.research_project_id
          data = {updated_at: now}
        }
      
        db.get research_reports {
          field_name = "id"
          field_value = $input.report_id
        } as $current
      
        db.get research_projects {
          field_name = "id"
          field_value = $current.research_project_id
        } as $project
      
        precondition ($current.status == "in_review") {
          error_type = "inputerror"
          error = "INVALID_TRANSITION: Only reports in review can be approved"
        }
      
        precondition ($current.based_on_revision == $project.content_revision) {
          error_type = "inputerror"
          error = "STALE_REPORT: Evidence changed after this report was generated; generate a new version"
        }
      
        precondition ((($current.report_json.blocking_issues ?? [])|count) == 0) {
          error_type = "inputerror"
          error = "BLOCKING_ISSUES: Resolve the report's blocking issues first"
        }
      
        function.run "reports/report_hash" {
          input = {report_id: $current.id}
        } as $hash
      
        precondition ($hash == $current.report_json_hash) {
          error_type = "inputerror"
          error = "INTEGRITY_ERROR: Stored report content does not match its recorded hash"
        }
      
        var $manifest_text {
          value = ""
        }
      
        foreach ($current.report_json.source_manifest.sources) {
          each as $entry {
            db.get research_sources {
              field_name = "id"
              field_value = $entry.source_id
            } as $source
          
            var.update $manifest_text {
              value = $manifest_text ~ ($entry.source_id|to_text) ~ ":" ~ ($source.content_hash ?? "none") ~ "|"
            }
          
            db.add research_report_sources {
              data = {
                created_at              : now
                organization_id         : $current.organization_id
                research_project_id     : $current.research_project_id
                report_id               : $current.id
                source_id               : $entry.source_id
                content_hash_at_approval: $source.content_hash
              }
            }
          }
        }
      
        precondition (($manifest_text|sha256) == $current.source_manifest_hash) {
          error_type = "inputerror"
          error = "STALE_REPORT: Source content changed after this report was generated"
        }
      
        db.query research_reports {
          where = $db.research_reports.research_project_id == $current.research_project_id && $db.research_reports.status == "approved"
          return = {type: "list"}
        } as $previous
      
        foreach ($previous) {
          each as $old {
            db.edit research_reports {
              field_name = "id"
              field_value = $old.id
              data = {status: "superseded", updated_at: now}
            }
          
            function.run "audit/log_event" {
              input = {
                organization_id    : $old.organization_id
                research_project_id: $old.research_project_id
                actor_id           : $auth.id
                entity_type        : "research_reports"
                entity_id          : $old.id
                action             : "supersede"
                from_status        : "approved"
                to_status          : "superseded"
                details            : {superseded_by: $current.id}
              }
            } as $supersede_event
          }
        }
      
        db.edit research_reports {
          field_name = "id"
          field_value = $current.id
          data = {
            status            : "approved"
            approved_by       : $auth.id
            approved_at       : now
            approved_json_hash: $hash
            updated_at        : now
          }
        } as $approved
      
        db.edit research_projects {
          field_name = "id"
          field_value = $current.research_project_id
          data = {current_report_id: $current.id, updated_at: now}
        }
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $current.organization_id
            research_project_id: $current.research_project_id
            actor_id           : $auth.id
            entity_type        : "research_reports"
            entity_id          : $current.id
            action             : "approve"
            gate_code          : "R5_REPORT"
            from_status        : "in_review"
            to_status          : "approved"
            reason             : $input.note
            after_hash         : $hash
            details            : {
            version_no          : $current.version_no
            source_manifest_hash: $current.source_manifest_hash
          }
          }
        } as $event
      }
    }
  }

  response = {report: $approved, idempotent: false}
  guid = "du-qK9yBXNazFonwrkDhlK1CHCM"
}
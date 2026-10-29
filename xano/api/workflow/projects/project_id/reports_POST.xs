// Generate a draft Research Report version from approved project data.
// Idempotent per project content revision: repeating the call without evidence changes returns the same report.
query "projects/{project_id}/reports" verb=POST {
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
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    var $idempotency_key {
      value = "report_render:" ~ ($input.project_id|to_text) ~ ":r" ~ ($pc.project.content_revision|to_text)
    }
  
    db.query jobs {
      where = $db.jobs.organization_id == $pc.project.organization_id && $db.jobs.idempotency_key == $idempotency_key
      return = {type: "single"}
    } as $existing_job
  
    conditional {
      if ($existing_job != null) {
        db.query research_reports {
          where = $db.research_reports.generated_job_id == $existing_job.id
          return = {type: "single"}
        } as $existing_report
      
        conditional {
          if ($existing_report != null) {
            return {
              value = {report: $existing_report, duplicate: true}
            }
          }
        }
      }
    }
  
    function.run "reports/build_snapshot" {
      input = {project_id: $input.project_id}
    } as $snapshot
  
    db.query research_reports {
      where = $db.research_reports.research_project_id == $input.project_id
      sort = {version_no: "desc"}
      return = {type: "single"}
    } as $last
  
    var $version_no {
      value = (($last|get:"version_no") ?? 0) + 1
    }
  
    db.transaction {
      stack {
        db.add jobs {
          data = {
            created_at           : now
            organization_id      : $pc.project.organization_id
            research_project_id  : $input.project_id
            job_type             : "report_render"
            status               : "running"
            idempotency_key      : $idempotency_key
            input_hash           : $idempotency_key|sha256
            output_schema_version: "1.0"
            attempt_count        : 1
            started_at           : now
            created_by           : $auth.id
          }
        } as $job
      
        db.add research_reports {
          data = {
            created_at            : now
            organization_id       : $pc.project.organization_id
            research_project_id   : $input.project_id
            version_no            : $version_no
            status                : "draft"
            schema_version        : "1.0"
            report_json           : $snapshot.report_json
            report_markdown       : $snapshot.report_markdown
            report_json_hash      : "pending"
            source_manifest_hash  : $snapshot.manifest_hash
            based_on_revision     : $pc.project.content_revision
            methodology_version_id: $pc.project.methodology_version_id
            generated_job_id      : $job.id
            generated_by          : $auth.id
          }
        } as $report
      
        function.run "reports/report_hash" {
          input = {report_id: $report.id}
        } as $hash
      
        db.edit research_reports {
          field_name = "id"
          field_value = $report.id
          data = {report_json_hash: $hash}
        }
      
        db.edit jobs {
          field_name = "id"
          field_value = $job.id
          data = {
            status     : "succeeded"
            finished_at: now
            updated_at : now
            output_json: {
            report_id       : $report.id
            version_no      : $version_no
            report_json_hash: $hash
          }
          }
        }
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "research_reports"
            entity_id          : $report.id
            action             : "generate"
            to_status          : "draft"
            after_hash         : $hash
            details            : {
            version_no       : $version_no
            based_on_revision: $pc.project.content_revision
            blocking_issues  : $snapshot.blocking_issues
          }
          }
        } as $event
      }
    }
  
    db.get research_reports {
      field_name = "id"
      field_value = $report.id
    } as $saved
  }

  response = {report: $saved, duplicate: false}
  guid = "7he6paBnrsFdTq0aezpoGiE1p9E"
}
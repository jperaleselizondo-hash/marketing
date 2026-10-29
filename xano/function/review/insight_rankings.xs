// Review transition for insight_rankings (shared state machine in workflow/next_status).
// Approval-specific integrity checks run before the status change; every change bumps the project revision and is audited.
function "review/insight_rankings" {
  input {
    int user_id
    int entity_id
    text decision
    text? reason?
  }

  stack {
    db.get insight_rankings {
      field_name = "id"
      field_value = $input.entity_id
    } as $row
  
    precondition ($row != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Item not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $input.user_id
        project_id: $row.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    function.run "workflow/next_status" {
      input = {
        current_status: $row.review_status
        decision      : $input.decision
        rank          : $pc.ctx.rank
        reason        : $input.reason
      }
    } as $to_status
  
    var $updates {
      value = {review_status: $to_status, updated_at: now}
    }
  
    conditional {
      if ($input.decision != "submit") {
        var.update $updates {
          value = $updates|set:"reviewed_by":$input.user_id
        }
      }
    }
  
    conditional {
      if ($to_status == "approved") {
        db.get research_insights {
          field_name = "id"
          field_value = $row.insight_id
        } as $insight
      
        precondition ($insight != null && $insight.status == "approved") {
          error_type = "inputerror"
          error = "INSIGHT_NOT_APPROVED: Rankings require an approved insight"
        }
      
        function.run "synthesis/evidence_counts" {
          input = {insight_id: $row.insight_id}
        } as $counts
      
        var.update $updates {
          value = $updates
            |set:"evidence_count":$counts.evidence_count
            |set:"independent_source_count":$counts.independent_source_count
            |set:"independent_speaker_count":$counts.independent_speaker_count
        }
      }
    }
  
    var $gate_code {
      value = null
    }
  
    conditional {
      if ($to_status == "approved") {
        var.update $gate_code {
          value = "R4_INSIGHTS"
        }
      }
    }
  
    db.transaction {
      stack {
        db.patch insight_rankings {
          field_name = "id"
          field_value = $row.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $row.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $row.organization_id
            research_project_id: $row.research_project_id
            actor_id           : $input.user_id
            entity_type        : "insight_rankings"
            entity_id          : $row.id
            action             : $input.decision
            gate_code          : $gate_code
            from_status        : $row.review_status
            to_status          : $to_status
            reason             : $input.reason
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "KrETwnCdacCdc_zrIObrw-SU72Q"
}
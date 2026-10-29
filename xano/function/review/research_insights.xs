// Review transition for research_insights (shared state machine in workflow/next_status).
// Approval-specific integrity checks run before the status change; every change bumps the project revision and is audited.
function "review/research_insights" {
  input {
    int user_id
    int entity_id
    text decision
    text? reason?
  }

  stack {
    db.get research_insights {
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
        current_status: $row.status
        decision      : $input.decision
        rank          : $pc.ctx.rank
        reason        : $input.reason
      }
    } as $to_status
  
    var $updates {
      value = {status: $to_status, updated_at: now}
    }
  
    conditional {
      if ($input.decision != "submit") {
        var.update $updates {
          value = $updates
            |set:"reviewer_id":$input.user_id
            |set:"reviewed_at":now
        }
      }
    }
  
    conditional {
      if ($to_status == "approved" && $row.origin == "ai_proposed") {
        var.update $updates {
          value = $updates
            |set:"accepted_by":$input.user_id
            |set:"accepted_at":now
        }
      }
    }
  
    conditional {
      if ($to_status == "approved") {
        conditional {
          if ($row.evidence_basis == "evidenced") {
            function.run "synthesis/evidence_counts" {
              input = {insight_id: $row.id}
            } as $counts
          
            precondition ($counts.evidence_count > 0) {
              error_type = "inputerror"
              error = "EVIDENCE_REQUIRED: An evidenced insight needs at least one approved supporting observation; approve as a hypothesis instead"
            }
          }
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
        db.patch research_insights {
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
            entity_type        : "research_insights"
            entity_id          : $row.id
            action             : $input.decision
            gate_code          : $gate_code
            from_status        : $row.status
            to_status          : $to_status
            reason             : $input.reason
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "Z8F7zaUt_3ywp-83OmamE16-8pk"
}
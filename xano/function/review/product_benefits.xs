// Review transition for product_benefits (shared state machine in workflow/next_status).
// Approval-specific integrity checks run before the status change; every change bumps the project revision and is audited.
function "review/product_benefits" {
  input {
    int user_id
    int entity_id
    text decision
    text? reason?
  }

  stack {
    db.get product_benefits {
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
      if ($to_status == "approved" && $row.origin == "ai_proposed") {
        var.update $updates {
          value = $updates
            |set:"accepted_by":$input.user_id
            |set:"accepted_at":now
        }
      }
    }
  
    var $gate_code {
      value = null
    }
  
    conditional {
      if ($to_status == "approved") {
        var.update $gate_code {
          value = "R1_PRODUCT_FACTS"
        }
      }
    }
  
    db.transaction {
      stack {
        db.patch product_benefits {
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
            entity_type        : "product_benefits"
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
  guid = "9KzQpbILSIu4rZT2T1_ekApG1v0"
}
// Project lifecycle: draft -> scoped -> collecting <-> synthesizing; any -> archived (owner); archived -> collecting (owner).
// draft -> scoped is gate R0_SCOPE and requires at least one segment.
query "projects/{project_id}/transition" verb=POST {
  api_group = "research"
  auth = "user"

  input {
    int project_id
    enum to_status {
      values = ["draft", "scoped", "collecting", "synthesizing", "archived"]
    }
  
    text? reason?
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "editor"
      }
    } as $pc
  
    var $from {
      value = $pc.project.status
    }
  
    var $allowed {
      value = {
        draft       : ["scoped", "archived"]
        scoped      : ["draft", "collecting", "archived"]
        collecting  : ["synthesizing", "archived"]
        synthesizing: ["collecting", "archived"]
        archived    : ["collecting"]
      }
    }
  
    precondition (($allowed|get:$from)|in:$input.to_status) {
      error_type = "inputerror"
      error = "INVALID_TRANSITION: cannot move project from " ~ $from ~ " to " ~ $input.to_status
    }
  
    precondition (($input.to_status != "archived" && $from != "archived") || $pc.ctx.rank >= 4) {
      error_type = "accessdenied"
      error = "FORBIDDEN: Only owners can archive or restore projects"
    }
  
    precondition ($input.to_status != "archived" || (($input.reason ?? "")|strlen) > 0) {
      error_type = "inputerror"
      error = "REASON_REQUIRED: Archiving requires a reason"
    }
  
    var $gate {
      value = null
    }
  
    conditional {
      if ($input.to_status == "scoped") {
        db.query research_segments {
          where = $db.research_segments.research_project_id == $input.project_id
          return = {type: "count"}
        } as $segment_count
      
        precondition ($segment_count > 0) {
          error_type = "inputerror"
          error = "GATE_R0_SCOPE: Define at least one audience segment before scoping"
        }
      
        var.update $gate {
          value = "R0_SCOPE"
        }
      }
    }
  
    db.transaction {
      stack {
        db.edit research_projects {
          field_name = "id"
          field_value = $input.project_id
          data = {status: $input.to_status, updated_at: now}
        }
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "research_projects"
            entity_id          : $input.project_id
            action             : "transition"
            gate_code          : $gate
            from_status        : $from
            to_status          : $input.to_status
            reason             : $input.reason
          }
        } as $event
      }
    }
  
    db.get research_projects {
      field_name = "id"
      field_value = $input.project_id
    } as $project
  }

  response = $project
  guid = "ez1GyOPYu2jyz-Hlce2YDD5awNQ"
}
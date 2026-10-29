query "competitors/{competitor_id}" verb=PATCH {
  api_group = "competitors"
  auth = "user"

  input {
    int competitor_id
    text? name? filters=trim
    text? website?
    enum? alternative_type? {
      values = ["direct", "indirect", "substitute"]
    }
  
    text? positioning_summary?
  }

  stack {
    db.get competitors {
      field_name = "id"
      field_value = $input.competitor_id
    } as $competitor
  
    precondition ($competitor != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Competitor not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $competitor.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ($competitor.review_status == "candidate") {
      error_type = "inputerror"
      error = "IMMUTABLE: Only candidate items can be edited; reopen it first"
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"website":$input.website|set_ifnotnull:"alternative_type":$input.alternative_type|set_ifnotnull:"positioning_summary":$input.positioning_summary
    }
  
    conditional {
      if ($input.name != null) {
        precondition (($input.name|strlen) > 0) {
          error_type = "inputerror"
          error = "VALIDATION: name cannot be empty"
        }
      
        var $normalized {
          value = "/[[:space:]]+/"
            |regex_replace:" ":($input.name|trim|to_lower)
        }
      
        conditional {
          if ($normalized != $competitor.normalized_name) {
            db.query competitors {
              where = $db.competitors.research_project_id == $competitor.research_project_id && $db.competitors.normalized_name == $normalized
              return = {type: "exists"}
            } as $exists
          
            precondition ($exists == false) {
              error_type = "inputerror"
              error = "DUPLICATE: A competitor with this name already exists in the project"
            }
          }
        }
      
        var.update $updates {
          value = $updates
            |set:"name":$input.name
            |set:"normalized_name":$normalized
        }
      }
    }
  
    db.transaction {
      stack {
        db.patch competitors {
          field_name = "id"
          field_value = $competitor.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $competitor.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $competitor.organization_id
            research_project_id: $competitor.research_project_id
            actor_id           : $auth.id
            entity_type        : "competitors"
            entity_id          : $competitor.id
            action             : "update"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "H-NtHgrDiVRXbk_xwGLYx1Pei5w"
}
query "competitor-observations/{competitor_observation_id}" verb=PATCH {
  api_group = "competitors"
  auth = "user"

  input {
    int competitor_observation_id
    enum? dimension? {
      values = [
        "idea"
        "usp"
        "pain_focus"
        "desire_focus"
        "social_media"
        "ads"
        "praise"
        "complaint"
      ]
    }
  
    text? observed_claim?
    text? analyst_note?
    timestamp? observed_on?
  }

  stack {
    db.get competitor_observations {
      field_name = "id"
      field_value = $input.competitor_observation_id
    } as $observation
  
    precondition ($observation != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Competitor observation not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $observation.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ($observation.review_status == "candidate") {
      error_type = "inputerror"
      error = "IMMUTABLE: Only candidate items can be edited; reopen it first"
    }
  
    precondition ($input.observed_claim == null || ($input.observed_claim|trim|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: observed_claim cannot be empty"
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"dimension":$input.dimension|set_ifnotnull:"observed_claim":$input.observed_claim|set_ifnotnull:"analyst_note":$input.analyst_note|set_ifnotnull:"observed_on":$input.observed_on
    }
  
    db.transaction {
      stack {
        db.patch competitor_observations {
          field_name = "id"
          field_value = $observation.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $observation.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $observation.organization_id
            research_project_id: $observation.research_project_id
            actor_id           : $auth.id
            entity_type        : "competitor_observations"
            entity_id          : $observation.id
            action             : "update"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "58DYtaE0qHtaTsuTxVXrPC8fXCw"
}
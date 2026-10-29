query "benefits/{benefit_id}" verb=PATCH {
  api_group = "product"
  auth = "user"

  input {
    int benefit_id
    text? benefit_text?
    enum? benefit_type? {
      values = ["functional", "emotional", "economic", "social", "other"]
    }
  }

  stack {
    db.get product_benefits {
      field_name = "id"
      field_value = $input.benefit_id
    } as $benefit
  
    precondition ($benefit != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Benefit not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $benefit.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ($benefit.review_status == "candidate") {
      error_type = "inputerror"
      error = "IMMUTABLE: Only candidate items can be edited; reopen it first"
    }
  
    precondition ($input.benefit_text == null || ($input.benefit_text|trim|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: benefit_text cannot be empty"
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"benefit_text":$input.benefit_text|set_ifnotnull:"benefit_type":$input.benefit_type
    }
  
    db.transaction {
      stack {
        db.patch product_benefits {
          field_name = "id"
          field_value = $benefit.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $benefit.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $benefit.organization_id
            research_project_id: $benefit.research_project_id
            actor_id           : $auth.id
            entity_type        : "product_benefits"
            entity_id          : $benefit.id
            action             : "update"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "GP9_xcocB-xIhBdRxexhYU-RhQQ"
}
// Edit a capability while it is still unverified.
query "capabilities/{capability_id}" verb=PATCH {
  api_group = "product"
  auth = "user"

  input {
    int capability_id
    enum? capability_type? {
      values = ["feature", "service", "performance", "limitation"]
    }
  
    text? description?
    enum? availability_status? {
      values = ["live", "beta", "roadmap", "discontinued"]
    }
  }

  stack {
    db.get product_capabilities {
      field_name = "id"
      field_value = $input.capability_id
    } as $capability
  
    precondition ($capability != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Capability not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $capability.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ($capability.verification_status == "unverified") {
      error_type = "inputerror"
      error = "IMMUTABLE: Only unverified capabilities can be edited; unverify it first"
    }
  
    precondition ($input.description == null || ($input.description|trim|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: description cannot be empty"
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"capability_type":$input.capability_type|set_ifnotnull:"description":$input.description|set_ifnotnull:"availability_status":$input.availability_status
    }
  
    db.transaction {
      stack {
        db.patch product_capabilities {
          field_name = "id"
          field_value = $capability.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $capability.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $capability.organization_id
            research_project_id: $capability.research_project_id
            actor_id           : $auth.id
            entity_type        : "product_capabilities"
            entity_id          : $capability.id
            action             : "update"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "jUq3zp7UisxYq_aeDSfyAxgQpA8"
}
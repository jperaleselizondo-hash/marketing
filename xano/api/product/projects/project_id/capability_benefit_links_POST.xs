// Link a product capability to a benefit it delivers. Both must belong to the project.
query "projects/{project_id}/capability-benefit-links" verb=POST {
  api_group = "product"
  auth = "user"

  input {
    int project_id
    int capability_id
    int benefit_id
    text? rationale?
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
  
    db.get product_capabilities {
      field_name = "id"
      field_value = $input.capability_id
    } as $capability
  
    precondition ($capability != null && $capability.research_project_id == $input.project_id) {
      error_type = "notfound"
      error = "NOT_FOUND: Capability not found in this project"
    }
  
    db.get product_benefits {
      field_name = "id"
      field_value = $input.benefit_id
    } as $benefit
  
    precondition ($benefit != null && $benefit.research_project_id == $input.project_id) {
      error_type = "notfound"
      error = "NOT_FOUND: Benefit not found in this project"
    }
  
    precondition ($benefit.review_status != "rejected" && $capability.verification_status != "disputed") {
      error_type = "inputerror"
      error = "VALIDATION: Cannot link a rejected benefit or a disputed capability"
    }
  
    db.query capability_benefit_links {
      where = $db.capability_benefit_links.capability_id == $capability.id && $db.capability_benefit_links.benefit_id == $benefit.id
      return = {type: "exists"}
    } as $exists
  
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "DUPLICATE: This capability is already linked to this benefit"
    }
  
    db.transaction {
      stack {
        db.add capability_benefit_links {
          data = {
            created_at         : now
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            capability_id      : $capability.id
            benefit_id         : $benefit.id
            rationale          : $input.rationale
            review_status      : "candidate"
            origin             : "human_entered"
            created_by         : $auth.id
          }
        } as $link
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "capability_benefit_links"
            entity_id          : $link.id
            action             : "create"
            to_status          : "candidate"
          }
        } as $event
      }
    }
  }

  response = $link
  guid = "dPIY0GlXe3zdS7dbXfr2cY0eGwI"
}
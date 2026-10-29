query "projects/{project_id}/capabilities" verb=POST {
  api_group = "product"
  auth = "user"

  input {
    int project_id
    enum capability_type {
      values = ["feature", "service", "performance", "limitation"]
    }
  
    text description
    enum availability_status {
      values = ["live", "beta", "roadmap", "discontinued"]
    }
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
  
    precondition (($input.description|trim|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: description is required"
    }
  
    db.transaction {
      stack {
        db.add product_capabilities {
          data = {
            created_at         : now
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            product_id         : $pc.project.product_id
            capability_type    : $input.capability_type
            description        : $input.description
            availability_status: $input.availability_status
            verification_status: "unverified"
            origin             : "human_entered"
            created_by         : $auth.id
          }
        } as $capability
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "product_capabilities"
            entity_id          : $capability.id
            action             : "create"
            to_status          : "unverified"
          }
        } as $event
      }
    }
  }

  response = $capability
  guid = "i8rZW4baHmr26P29zBHyMYyh8Wk"
}
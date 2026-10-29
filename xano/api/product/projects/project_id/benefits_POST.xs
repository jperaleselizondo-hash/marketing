query "projects/{project_id}/benefits" verb=POST {
  api_group = "product"
  auth = "user"

  input {
    int project_id
    text benefit_text
    enum benefit_type {
      values = ["functional", "emotional", "economic", "social", "other"]
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
  
    precondition (($input.benefit_text|trim|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: benefit_text is required"
    }
  
    db.transaction {
      stack {
        db.add product_benefits {
          data = {
            created_at         : now
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            benefit_text       : $input.benefit_text
            benefit_type       : $input.benefit_type
            review_status      : "candidate"
            origin             : "human_entered"
            created_by         : $auth.id
          }
        } as $benefit
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "product_benefits"
            entity_id          : $benefit.id
            action             : "create"
            to_status          : "candidate"
          }
        } as $event
      }
    }
  }

  response = $benefit
  guid = "ShOo6o75TPEzAgZojPLnyK2cqsc"
}
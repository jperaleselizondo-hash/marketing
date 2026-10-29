query "projects/{project_id}/segments" verb=POST {
  api_group = "research"
  auth = "user"

  input {
    int project_id
    text name filters=trim
    enum segment_type {
      values = ["buyer", "supplier", "end_user", "influencer", "other"]
    }
  
    text? geography?
    text? locale? filters=trim
    text? description?
    enum? awareness_hypothesis? {
      values = [
        "unaware"
        "problem_aware"
        "solution_aware"
        "product_aware"
        "most_aware"
      ]
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
  
    precondition (($input.name|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: name is required"
    }
  
    db.query research_segments {
      where = $db.research_segments.research_project_id == $input.project_id && $db.research_segments.name == $input.name
      return = {type: "exists"}
    } as $exists
  
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "DUPLICATE: A segment with this name already exists in the project"
    }
  
    db.transaction {
      stack {
        db.add research_segments {
          data = {
            created_at          : now
            organization_id     : $pc.project.organization_id
            research_project_id : $input.project_id
            name                : $input.name
            segment_type        : $input.segment_type
            geography           : $input.geography
            locale              : $input.locale
            description         : $input.description
            awareness_hypothesis: $input.awareness_hypothesis
            created_by          : $auth.id
          }
        } as $segment
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "research_segments"
            entity_id          : $segment.id
            action             : "create"
          }
        } as $event
      }
    }
  }

  response = $segment
  guid = "UzIIsdraPTfTSL40WqGDOUCgPCk"
}
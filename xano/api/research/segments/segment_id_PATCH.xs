query "segments/{segment_id}" verb=PATCH {
  api_group = "research"
  auth = "user"

  input {
    int segment_id
    text? name? filters=trim
    enum? segment_type? {
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
    db.get research_segments {
      field_name = "id"
      field_value = $input.segment_id
    } as $segment
  
    precondition ($segment != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Segment not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $segment.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    conditional {
      if ($input.name != null && $input.name != $segment.name) {
        db.query research_segments {
          where = $db.research_segments.research_project_id == $segment.research_project_id && $db.research_segments.name == $input.name
          return = {type: "exists"}
        } as $exists
      
        precondition ($exists == false && ($input.name|strlen) > 0) {
          error_type = "inputerror"
          error = "DUPLICATE: A segment with this name already exists in the project"
        }
      }
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"name":$input.name|set_ifnotnull:"segment_type":$input.segment_type|set_ifnotnull:"geography":$input.geography|set_ifnotnull:"locale":$input.locale|set_ifnotnull:"description":$input.description|set_ifnotnull:"awareness_hypothesis":$input.awareness_hypothesis
    }
  
    db.transaction {
      stack {
        db.patch research_segments {
          field_name = "id"
          field_value = $segment.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $segment.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $segment.organization_id
            research_project_id: $segment.research_project_id
            actor_id           : $auth.id
            entity_type        : "research_segments"
            entity_id          : $segment.id
            action             : "update"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "LHeKlg497g9zr4HQib1hPFTteOQ"
}
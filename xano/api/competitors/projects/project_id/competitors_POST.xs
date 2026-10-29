query "projects/{project_id}/competitors" verb=POST {
  api_group = "competitors"
  auth = "user"

  input {
    int project_id
    text name filters=trim
    text? website?
    enum alternative_type {
      values = ["direct", "indirect", "substitute"]
    }
  
    text? positioning_summary?
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
  
    var $normalized {
      value = "/[[:space:]]+/"
        |regex_replace:" ":($input.name|trim|to_lower)
    }
  
    db.query competitors {
      where = $db.competitors.research_project_id == $input.project_id && $db.competitors.normalized_name == $normalized
      return = {type: "exists"}
    } as $exists
  
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "DUPLICATE: A competitor with this name already exists in the project"
    }
  
    db.transaction {
      stack {
        db.add competitors {
          data = {
            created_at         : now
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            name               : $input.name
            normalized_name    : $normalized
            website            : $input.website
            alternative_type   : $input.alternative_type
            positioning_summary: $input.positioning_summary
            review_status      : "candidate"
            created_by         : $auth.id
          }
        } as $competitor
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "competitors"
            entity_id          : $competitor.id
            action             : "create"
            to_status          : "candidate"
          }
        } as $event
      }
    }
  }

  response = $competitor
  guid = "QhyAFclvWc0QqCo9Vi4Eu47scXc"
}
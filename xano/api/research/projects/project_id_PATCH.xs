query "projects/{project_id}" verb=PATCH {
  api_group = "research"
  auth = "user"

  input {
    int project_id
    text? title? filters=trim
    text? objective?
    text? scope?
    text? target_geography?
    text? target_locale? filters=trim
    decimal? ai_budget_usd? filters=min:0
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
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"title":$input.title|set_ifnotnull:"objective":$input.objective|set_ifnotnull:"scope":$input.scope|set_ifnotnull:"target_geography":$input.target_geography|set_ifnotnull:"target_locale":$input.target_locale|set_ifnotnull:"ai_budget_usd":$input.ai_budget_usd
    }
  
    db.transaction {
      stack {
        db.patch research_projects {
          field_name = "id"
          field_value = $input.project_id
          data = $updates
        }
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "research_projects"
            entity_id          : $input.project_id
            action             : "update"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  
    db.get research_projects {
      field_name = "id"
      field_value = $input.project_id
    } as $project
  }

  response = $project
  guid = "DCRGMZd5ogNQE01uJgolaN5KlOw"
}
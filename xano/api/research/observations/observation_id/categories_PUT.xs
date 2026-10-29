// Replace the IVOC category set of a candidate observation.
query "observations/{observation_id}/categories" verb=PUT {
  api_group = "research"
  auth = "user"

  input {
    int observation_id
    text[] ivoc_categories
    enum? confidence? {
      values = ["low", "medium", "high"]
    }
  }

  stack {
    db.get research_observations {
      field_name = "id"
      field_value = $input.observation_id
    } as $observation
  
    precondition ($observation != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Observation not found"
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
  
    var $allowed_categories {
      value = [
        "pain_fear"
        "desire"
        "objection"
        "firm_belief"
        "shakable_belief"
        "vocabulary"
        "other"
      ]
    }
  
    var $categories {
      value = $input.ivoc_categories|unique
    }
  
    foreach ($categories) {
      each as $category {
        precondition ($allowed_categories|in:$category) {
          error_type = "inputerror"
          error = "VALIDATION: Unknown IVOC category " ~ $category
        }
      }
    }
  
    db.transaction {
      stack {
        db.bulk.delete observation_categories {
          where = $db.observation_categories.observation_id == $observation.id
        } as $removed
      
        foreach ($categories) {
          each as $category {
            db.add observation_categories {
              data = {
                created_at         : now
                organization_id    : $observation.organization_id
                research_project_id: $observation.research_project_id
                observation_id     : $observation.id
                ivoc_category      : $category
                confidence         : $input.confidence
                origin             : "human_entered"
                created_by         : $auth.id
              }
            }
          }
        }
      
        function.run "research/touch_project" {
          input = {project_id: $observation.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $observation.organization_id
            research_project_id: $observation.research_project_id
            actor_id           : $auth.id
            entity_type        : "research_observations"
            entity_id          : $observation.id
            action             : "categorize"
            details            : {categories: $categories}
          }
        } as $event
      }
    }
  }

  response = {
    observation_id : $observation.id
    ivoc_categories: $categories
  }

  guid = "EzxAoxeMV3HnMGZlEbwM7FkQB38"
}
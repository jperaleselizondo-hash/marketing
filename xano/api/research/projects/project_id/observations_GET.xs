// Observations with their IVOC categories. Optional filters: segment, type, review status, category.
query "projects/{project_id}/observations" verb=GET {
  api_group = "research"
  auth = "user"

  input {
    int project_id
    int? research_segment_id?
    enum? observation_type? {
      values = [
        "verbatim_quote"
        "paraphrase"
        "secondary_summary"
        "analyst_hypothesis"
      ]
    }
  
    enum? review_status? {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    enum? ivoc_category? {
      values = [
        "pain_fear"
        "desire"
        "objection"
        "firm_belief"
        "shakable_belief"
        "vocabulary"
        "other"
      ]
    }
  
    int page?=1 filters=min:1
    int per_page?=50 filters=min:1|max:200
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "viewer"
      }
    } as $pc
  
    conditional {
      if ($input.ivoc_category != null) {
        db.query research_observations {
          join = {
            observation_categories: {
              table: "observation_categories"
              where: $db.observation_categories.observation_id == $db.research_observations.id
            }
          }
        
          where = $db.research_observations.research_project_id == $input.project_id && $db.observation_categories.ivoc_category == $input.ivoc_category && $db.research_observations.research_segment_id ==? $input.research_segment_id && $db.research_observations.observation_type ==? $input.observation_type && $db.research_observations.review_status ==? $input.review_status
          sort = {id: "asc"}
          return = {
            type  : "list"
            paging: {
              page    : $input.page
              per_page: $input.per_page
              totals  : true
            }
          }
        } as $result
      }
    
      else {
        db.query research_observations {
          where = $db.research_observations.research_project_id == $input.project_id && $db.research_observations.research_segment_id ==? $input.research_segment_id && $db.research_observations.observation_type ==? $input.observation_type && $db.research_observations.review_status ==? $input.review_status
          sort = {id: "asc"}
          return = {
            type  : "list"
            paging: {
              page    : $input.page
              per_page: $input.per_page
              totals  : true
            }
          }
        } as $result
      }
    }
  
    db.query observation_categories {
      where = $db.observation_categories.research_project_id == $input.project_id
      return = {type: "list"}
    } as $all_categories
  
    var $by_observation {
      value = $all_categories|index_by:"observation_id"
    }
  
    var $items {
      value = []
    }
  
    var $item_rows {
      value = []
    }
  
    var $item_categories {
      value = []
    }
  
    foreach ($result.items) {
      each as $item {
        var.update $item_rows {
          value = ($by_observation|get:($item.id|to_text)) ?? []
        }
      
        var.update $item_categories {
          value = $item_rows|map:$$.ivoc_category
        }
      
        var.update $items {
          value = $items
            |push:($item
              |set:"ivoc_categories":$item_categories
            )
        }
      }
    }
  }

  response = $result|set:"items":$items
  guid = "r34VVhkMqVbkeorlgvVt2s4xNxI"
}
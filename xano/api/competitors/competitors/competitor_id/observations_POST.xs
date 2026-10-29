// Record what a competitor says or does along one dimension. observed_claim (the competitor's claim) and
// analyst_note (our interpretation) stay separate; a competitor claim is never independent proof.
query "competitors/{competitor_id}/observations" verb=POST {
  api_group = "competitors"
  auth = "user"

  input {
    int competitor_id
    enum dimension {
      values = [
        "idea"
        "usp"
        "pain_focus"
        "desire_focus"
        "social_media"
        "ads"
        "praise"
        "complaint"
      ]
    }
  
    text observed_claim
    text? analyst_note?
    int? source_excerpt_id?
    int? observation_id?
    timestamp? observed_on?
  }

  stack {
    db.get competitors {
      field_name = "id"
      field_value = $input.competitor_id
    } as $competitor
  
    precondition ($competitor != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Competitor not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $competitor.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition (($input.observed_claim|trim|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: observed_claim is required"
    }
  
    var $provenance {
      value = "unverified"
    }
  
    conditional {
      if ($input.source_excerpt_id != null) {
        db.get source_excerpts {
          field_name = "id"
          field_value = $input.source_excerpt_id
        } as $excerpt
      
        precondition ($excerpt != null && $excerpt.research_project_id == $competitor.research_project_id) {
          error_type = "notfound"
          error = "NOT_FOUND: Excerpt not found in this project"
        }
      
        conditional {
          if ($excerpt.verification_status == "verified") {
            var.update $provenance {
              value = "verified"
            }
          }
        }
      }
    }
  
    conditional {
      if ($input.observation_id != null) {
        db.get research_observations {
          field_name = "id"
          field_value = $input.observation_id
        } as $observation
      
        precondition ($observation != null && $observation.research_project_id == $competitor.research_project_id) {
          error_type = "notfound"
          error = "NOT_FOUND: Observation not found in this project"
        }
      }
    }
  
    db.transaction {
      stack {
        db.add competitor_observations {
          data = {
            created_at         : now
            organization_id    : $competitor.organization_id
            research_project_id: $competitor.research_project_id
            competitor_id      : $competitor.id
            dimension          : $input.dimension
            observed_claim     : $input.observed_claim
            analyst_note       : $input.analyst_note
            source_excerpt_id  : $input.source_excerpt_id
            observation_id     : $input.observation_id
            observed_on        : $input.observed_on
            provenance_status  : $provenance
            review_status      : "candidate"
            origin             : "human_entered"
            created_by         : $auth.id
          }
        } as $competitor_observation
      
        function.run "research/touch_project" {
          input = {project_id: $competitor.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $competitor.organization_id
            research_project_id: $competitor.research_project_id
            actor_id           : $auth.id
            entity_type        : "competitor_observations"
            entity_id          : $competitor_observation.id
            action             : "create"
            to_status          : "candidate"
          }
        } as $event
      }
    }
  }

  response = $competitor_observation
  guid = "CYth_3omvg45e2Zfe4Ta-HO6X7U"
}
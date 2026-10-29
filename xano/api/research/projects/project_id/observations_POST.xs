// Record a research observation. verbatim_quote must cite a verified excerpt and always takes the excerpt's exact text.
// provenance_status is derived (verified only when the cited excerpt is verified), never client-supplied.
query "projects/{project_id}/observations" verb=POST {
  api_group = "research"
  auth = "user"

  input {
    int project_id
    int? research_segment_id?
    int? source_excerpt_id?
    enum observation_type {
      values = [
        "verbatim_quote"
        "paraphrase"
        "secondary_summary"
        "analyst_hypothesis"
      ]
    }
  
    text? original_text?
    text? language_code? filters=trim|lower
    text? speaker_handle?
    enum? speaker_role? {
      values = [
        "buyer"
        "supplier"
        "prospect"
        "customer"
        "competitor"
        "expert"
        "owner"
        "unknown"
      ]
    }
  
    text[]? ivoc_categories?
    enum? category_confidence? {
      values = ["low", "medium", "high"]
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
  
    conditional {
      if ($input.research_segment_id != null) {
        db.get research_segments {
          field_name = "id"
          field_value = $input.research_segment_id
        } as $segment
      
        precondition ($segment != null && $segment.research_project_id == $input.project_id) {
          error_type = "notfound"
          error = "NOT_FOUND: Segment not found in this project"
        }
      }
    }
  
    var $excerpt {
      value = null
    }
  
    conditional {
      if ($input.source_excerpt_id != null) {
        db.get source_excerpts {
          field_name = "id"
          field_value = $input.source_excerpt_id
        } as $found_excerpt
      
        precondition ($found_excerpt != null && $found_excerpt.research_project_id == $input.project_id) {
          error_type = "notfound"
          error = "NOT_FOUND: Excerpt not found in this project"
        }
      
        var.update $excerpt {
          value = $found_excerpt
        }
      }
    }
  
    var $text {
      value = $input.original_text
    }
  
    conditional {
      if ($input.observation_type == "verbatim_quote") {
        precondition ($excerpt != null && $excerpt.verification_status == "verified") {
          error_type = "inputerror"
          error = "EXCERPT_NOT_VERIFIED: A verbatim quote must cite a verified excerpt"
        }
      
        precondition ($input.original_text == null || $input.original_text == $excerpt.exact_text) {
          error_type = "inputerror"
          error = "VERBATIM_MISMATCH: A verbatim quote must match the excerpt text exactly"
        }
      
        var.update $text {
          value = $excerpt.exact_text
        }
      }
    }
  
    precondition (((($text ?? "")|trim)|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: original_text is required"
    }
  
    var $language {
      value = $input.language_code ?? $excerpt.language_code
    }
  
    precondition ((($language ?? "")|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: language_code is required when no excerpt is cited"
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
      value = ($input.ivoc_categories ?? [])|unique
    }
  
    foreach ($categories) {
      each as $category {
        precondition ($allowed_categories|in:$category) {
          error_type = "inputerror"
          error = "VALIDATION: Unknown IVOC category " ~ $category
        }
      }
    }
  
    function.run "privacy/pseudonymize" {
      input = {
        organization_id: $pc.project.organization_id
        handle         : $input.speaker_handle
      }
    } as $speaker_ref
  
    var $provenance {
      value = ($excerpt != null && $excerpt.verification_status == "verified") ? "verified" : "unverified"
    }
  
    db.transaction {
      stack {
        db.add research_observations {
          data = {
            created_at         : now
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            research_segment_id: $input.research_segment_id
            source_excerpt_id  : $input.source_excerpt_id
            observation_type   : $input.observation_type
            original_text      : $text
            language_code      : $language
            speaker_ref        : $speaker_ref ?? $excerpt.speaker_ref
            speaker_role       : $input.speaker_role ?? $excerpt.speaker_role
            provenance_status  : $provenance
            review_status      : "candidate"
            revision           : 1
            origin             : "human_entered"
            created_by         : $auth.id
          }
        } as $observation
      
        foreach ($categories) {
          each as $category {
            db.add observation_categories {
              data = {
                created_at         : now
                organization_id    : $pc.project.organization_id
                research_project_id: $input.project_id
                observation_id     : $observation.id
                ivoc_category      : $category
                confidence         : $input.category_confidence
                origin             : "human_entered"
                created_by         : $auth.id
              }
            }
          }
        }
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "research_observations"
            entity_id          : $observation.id
            action             : "create"
            to_status          : "candidate"
            details            : {
            observation_type : $input.observation_type
            provenance_status: $provenance
            categories       : $categories
          }
          }
        } as $event
      }
    }
  }

  response = $observation
    |set:"ivoc_categories":$categories
  guid = "vfan31D884Fntxc2nq9I2WShpRQ"
}
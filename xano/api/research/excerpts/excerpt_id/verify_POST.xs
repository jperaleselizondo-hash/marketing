// Reviewer verification of an excerpt. Sources with stored content are always re-checked by content match
// (a mismatch cannot be overridden). Without stored content, a reviewer must explicitly confirm the quote.
query "excerpts/{excerpt_id}/verify" verb=POST {
  api_group = "research"
  auth = "user"

  input {
    int excerpt_id
    bool human_confirmed?
    text? note?
  }

  stack {
    db.get source_excerpts {
      field_name = "id"
      field_value = $input.excerpt_id
    } as $excerpt
  
    precondition ($excerpt != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Excerpt not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $excerpt.research_project_id
        min_role  : "reviewer"
        for_write : true
      }
    } as $pc
  
    precondition ($excerpt.verification_status != "verified") {
      error_type = "inputerror"
      error = "INVALID_TRANSITION: Excerpt is already verified"
    }
  
    db.get research_sources {
      field_name = "id"
      field_value = $excerpt.source_id
    } as $source
  
    var $status {
      value = "pending_human"
    }
  
    var $method {
      value = null
    }
  
    conditional {
      if ((($source.content_text ?? "")|strlen) > 0) {
        function.run "research/text_contains" {
          input = {
            haystack: $source.content_text
            needle  : $excerpt.exact_text
          }
        } as $found
      
        var.update $status {
          value = $found ? "verified" : "failed"
        }
      
        var.update $method {
          value = "content_match"
        }
      }
    
      elseif ($input.human_confirmed) {
        var.update $status {
          value = "verified"
        }
      
        var.update $method {
          value = "human_review"
        }
      }
    }
  
    var $verified_by {
      value = null
    }
  
    var $verified_at {
      value = null
    }
  
    conditional {
      if ($status == "verified") {
        var.update $verified_by {
          value = $auth.id
        }
      
        var.update $verified_at {
          value = now
        }
      }
    }
  
    db.transaction {
      stack {
        db.edit source_excerpts {
          field_name = "id"
          field_value = $excerpt.id
          data = {
            verification_status: $status
            verification_method: $method
            verified_by        : $verified_by
            verified_at        : $verified_at
            updated_at         : now
          }
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $excerpt.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $excerpt.organization_id
            research_project_id: $excerpt.research_project_id
            actor_id           : $auth.id
            entity_type        : "source_excerpts"
            entity_id          : $excerpt.id
            action             : "verify"
            gate_code          : "R3_EVIDENCE"
            from_status        : $excerpt.verification_status
            to_status          : $status
            reason             : $input.note
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "Z_zfZOhDWogBOO0hM8UrqaN_sao"
}
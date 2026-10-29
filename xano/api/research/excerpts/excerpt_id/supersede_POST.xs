// Correct an excerpt by creating a new one that supersedes it. The original row is never altered.
query "excerpts/{excerpt_id}/supersede" verb=POST {
  api_group = "research"
  auth = "user"

  input {
    int excerpt_id
    text exact_text
    text? locator?
    text reason
  }

  stack {
    db.get source_excerpts {
      field_name = "id"
      field_value = $input.excerpt_id
    } as $old
  
    precondition ($old != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Excerpt not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $old.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ((($input.exact_text|trim)|strlen) > 0 && (($input.reason|trim)|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: exact_text and reason are required"
    }
  
    var $excerpt_hash {
      value = $input.exact_text|sha256
    }
  
    precondition ($excerpt_hash != $old.excerpt_hash) {
      error_type = "inputerror"
      error = "VALIDATION: The replacement text is identical to the original"
    }
  
    db.query source_excerpts {
      where = $db.source_excerpts.source_id == $old.source_id && $db.source_excerpts.excerpt_hash == $excerpt_hash
      return = {type: "exists"}
    } as $exists
  
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "DUPLICATE: This excerpt already exists for the source"
    }
  
    db.get research_sources {
      field_name = "id"
      field_value = $old.source_id
    } as $source
  
    var $verification {
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
            needle  : $input.exact_text
          }
        } as $found
      
        var.update $verification {
          value = $found ? "verified" : "failed"
        }
      
        var.update $method {
          value = "content_match"
        }
      }
    }
  
    var $verified_at {
      value = null
    }
  
    conditional {
      if ($verification == "verified") {
        var.update $verified_at {
          value = now
        }
      }
    }
  
    db.transaction {
      stack {
        db.add source_excerpts {
          data = {
            created_at           : now
            organization_id      : $old.organization_id
            research_project_id  : $old.research_project_id
            source_id            : $old.source_id
            exact_text           : $input.exact_text
            locator              : $input.locator ?? $old.locator
            captured_at          : now
            language_code        : $old.language_code
            excerpt_hash         : $excerpt_hash
            verification_status  : $verification
            verification_method  : $method
            verified_at          : $verified_at
            supersedes_excerpt_id: $old.id
            speaker_ref          : $old.speaker_ref
            speaker_role         : $old.speaker_role
            usage_rights         : $old.usage_rights
            personal_data_class  : $old.personal_data_class
            redaction_status     : "none"
            origin               : "human_entered"
            created_by           : $auth.id
          }
        } as $excerpt
      
        function.run "research/touch_project" {
          input = {project_id: $old.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $old.organization_id
            research_project_id: $old.research_project_id
            actor_id           : $auth.id
            entity_type        : "source_excerpts"
            entity_id          : $excerpt.id
            action             : "supersede"
            reason             : $input.reason
            before_hash        : $old.excerpt_hash
            after_hash         : $excerpt_hash
            details            : {supersedes_excerpt_id: $old.id}
          }
        } as $event
      }
    }
  }

  response = $excerpt
  guid = "L4PU2bqCiqrQ9AsAexIyL1n89hY"
}
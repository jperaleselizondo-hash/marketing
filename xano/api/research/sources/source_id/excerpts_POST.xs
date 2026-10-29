// Record a verbatim excerpt of a source. exact_text is immutable after creation.
// If the source has stored content, the excerpt is checked against it immediately:
// found -> verified (content_match), not found -> failed (a forged or altered quote). No stored content -> pending_human.
query "sources/{source_id}/excerpts" verb=POST {
  api_group = "research"
  auth = "user"

  input {
    int source_id
    text exact_text
    text? locator?
    text? language_code? filters=trim|lower
    timestamp? captured_at?
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
  
    enum? usage_rights? {
      values = [
        "internal_analysis_only"
        "paraphrase_permitted"
        "quote_anonymized_permitted"
        "quote_attributed_permitted"
        "prohibited"
        "undetermined"
      ]
    }
  
    enum? personal_data_class? {
      values = [
        "none"
        "pseudonymized"
        "identifiable"
        "special_category"
        "undetermined"
      ]
    }
  }

  stack {
    db.get research_sources {
      field_name = "id"
      field_value = $input.source_id
    } as $source
  
    precondition ($source != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Source not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $source.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ($source.review_status != "rejected") {
      error_type = "inputerror"
      error = "SOURCE_REJECTED: Cannot add excerpts to a rejected source"
    }
  
    precondition ((($input.exact_text|trim)|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: exact_text is required"
    }
  
    var $excerpt_hash {
      value = $input.exact_text|sha256
    }
  
    db.query source_excerpts {
      where = $db.source_excerpts.source_id == $source.id && $db.source_excerpts.excerpt_hash == $excerpt_hash
      return = {type: "single"}
    } as $existing
  
    conditional {
      if ($existing != null) {
        return {
          value = {excerpt: $existing, duplicate: true}
        }
      }
    }
  
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
  
    function.run "privacy/pseudonymize" {
      input = {
        organization_id: $source.organization_id
        handle         : $input.speaker_handle
      }
    } as $speaker_ref
  
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
            created_at         : now
            organization_id    : $source.organization_id
            research_project_id: $source.research_project_id
            source_id          : $source.id
            exact_text         : $input.exact_text
            locator            : $input.locator
            captured_at        : $input.captured_at ?? now
            language_code      : $input.language_code ?? $source.language_code
            excerpt_hash       : $excerpt_hash
            verification_status: $verification
            verification_method: $method
            verified_at        : $verified_at
            speaker_ref        : $speaker_ref
            speaker_role       : $input.speaker_role
            usage_rights       : $input.usage_rights
            personal_data_class: $input.personal_data_class
            redaction_status   : "none"
            origin             : "human_entered"
            created_by         : $auth.id
          }
        } as $excerpt
      
        function.run "research/touch_project" {
          input = {project_id: $source.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $source.organization_id
            research_project_id: $source.research_project_id
            actor_id           : $auth.id
            entity_type        : "source_excerpts"
            entity_id          : $excerpt.id
            action             : "create"
            to_status          : $verification
            after_hash         : $excerpt_hash
          }
        } as $event
      }
    }
  }

  response = {excerpt: $excerpt, duplicate: false}
  guid = "KgSkgGXV3klcDMn9MO2ep6ZwSqo"
}
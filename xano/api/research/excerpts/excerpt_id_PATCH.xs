// Update an excerpt's classification only (speaker, usage rights, personal data, redaction). exact_text never changes.
query "excerpts/{excerpt_id}" verb=PATCH {
  api_group = "research"
  auth = "user"

  input {
    int excerpt_id
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
  
    enum? redaction_status? {
      values = ["none", "redacted"]
    }
  
    text? locator?
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
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"speaker_role":$input.speaker_role|set_ifnotnull:"usage_rights":$input.usage_rights|set_ifnotnull:"personal_data_class":$input.personal_data_class|set_ifnotnull:"redaction_status":$input.redaction_status|set_ifnotnull:"locator":$input.locator
    }
  
    conditional {
      if ($input.speaker_handle != null) {
        function.run "privacy/pseudonymize" {
          input = {
            organization_id: $excerpt.organization_id
            handle         : $input.speaker_handle
          }
        } as $speaker_ref
      
        var.update $updates {
          value = $updates|set:"speaker_ref":$speaker_ref
        }
      }
    }
  
    db.transaction {
      stack {
        db.patch source_excerpts {
          field_name = "id"
          field_value = $excerpt.id
          data = $updates
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
            action             : "classify"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "x6SL-xVTW0U9-sZUBN_LKtXtDE4"
}
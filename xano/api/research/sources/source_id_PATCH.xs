// Update source metadata and its privacy / provenance / rights / retention classification.
// canonical_url is immutable (register a new source instead). content_text is locked once any excerpt is verified.
query "sources/{source_id}" verb=PATCH {
  api_group = "research"
  auth = "user"

  input {
    int source_id
    text? title? filters=trim
    text? publisher?
    text? author_handle?
    timestamp? published_at?
    text? content_text?
    text? storage_ref?
    enum? retrieval_status? {
      values = ["ok", "failed", "gone", "not_applicable"]
    }
  
    text? processing_basis_code?
    text? processing_basis_jurisdiction? filters=trim|upper
    enum? processing_basis_status? {
      values = ["not_applicable", "undetermined", "proposed", "legally_reviewed"]
    }
  
    text? privacy_policy_version?
    text? terms_note?
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
  
    text? usage_rights_basis?
    text? license_ref?
    enum? personal_data_class? {
      values = [
        "none"
        "pseudonymized"
        "identifiable"
        "special_category"
        "undetermined"
      ]
    }
  
    text? retention_rule_code?
    date? retention_until?
    enum? deletion_status? {
      values = ["active", "scheduled", "redacted", "tombstoned"]
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
  
    precondition ($input.processing_basis_status != "legally_reviewed" || $pc.ctx.rank >= 3) {
      error_type = "accessdenied"
      error = "FORBIDDEN: Only reviewers can record a legally reviewed processing basis"
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"title":$input.title|set_ifnotnull:"publisher":$input.publisher|set_ifnotnull:"published_at":$input.published_at|set_ifnotnull:"storage_ref":$input.storage_ref|set_ifnotnull:"retrieval_status":$input.retrieval_status|set_ifnotnull:"processing_basis_code":$input.processing_basis_code|set_ifnotnull:"processing_basis_jurisdiction":$input.processing_basis_jurisdiction|set_ifnotnull:"processing_basis_status":$input.processing_basis_status|set_ifnotnull:"privacy_policy_version":$input.privacy_policy_version|set_ifnotnull:"terms_note":$input.terms_note|set_ifnotnull:"usage_rights":$input.usage_rights|set_ifnotnull:"usage_rights_basis":$input.usage_rights_basis|set_ifnotnull:"license_ref":$input.license_ref|set_ifnotnull:"personal_data_class":$input.personal_data_class|set_ifnotnull:"retention_rule_code":$input.retention_rule_code|set_ifnotnull:"retention_until":$input.retention_until|set_ifnotnull:"deletion_status":$input.deletion_status
    }
  
    conditional {
      if ($input.processing_basis_status == "legally_reviewed") {
        var.update $updates {
          value = $updates
            |set:"processing_basis_reviewed_by":$auth.id
            |set:"processing_basis_reviewed_at":now
        }
      }
    }
  
    conditional {
      if ($input.author_handle != null) {
        function.run "privacy/pseudonymize" {
          input = {
            organization_id: $source.organization_id
            handle         : $input.author_handle
          }
        } as $author_ref
      
        var.update $updates {
          value = $updates|set:"author_ref":$author_ref
        }
      }
    }
  
    conditional {
      if ($input.content_text != null) {
        db.query source_excerpts {
          where = $db.source_excerpts.source_id == $source.id && $db.source_excerpts.verification_status == "verified"
          return = {type: "exists"}
        } as $has_verified
      
        precondition ($has_verified == false) {
          error_type = "inputerror"
          error = "SOURCE_CONTENT_LOCKED: Content cannot change after excerpts were verified against it"
        }
      
        var.update $updates {
          value = $updates
            |set:"content_text":$input.content_text
            |set:"content_hash":($input.content_text|sha256)
        }
      }
    }
  
    db.transaction {
      stack {
        db.patch research_sources {
          field_name = "id"
          field_value = $source.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $source.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $source.organization_id
            research_project_id: $source.research_project_id
            actor_id           : $auth.id
            entity_type        : "research_sources"
            entity_id          : $source.id
            action             : "update"
            before_hash        : $source.content_hash
            after_hash         : $updated.content_hash
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "qxzrQDLH-uImcYh_vkSiKOWBsY4"
}
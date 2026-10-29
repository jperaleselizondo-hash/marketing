// Register a research source. Deduplicates deterministically: same canonical URL (normalized) or same content
// in a project returns the existing source with duplicate=true. Author handles are stored only as pseudonyms.
query "projects/{project_id}/sources" verb=POST {
  api_group = "research"
  auth = "user"

  input {
    int project_id
    enum source_kind {
      values = [
        "public_web"
        "interview"
        "survey"
        "customer_document"
        "competitor_asset"
        "import"
        "owner_attestation"
      ]
    }
  
    text? canonical_url? filters=trim
    text title filters=trim
    text? publisher?
    text? author_handle?
    timestamp? published_at?
    timestamp? captured_at?
    text language_code filters=trim|lower
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
    enum acquisition_method {
      values = [
        "manual_capture"
        "owner_upload"
        "interview_record"
        "survey_export"
        "crm_export"
        "spreadsheet_import"
        "automated_fetch"
      ]
    }
  
    enum access_conditions {
      values = [
        "public_no_login"
        "login_required"
        "paywalled"
        "privately_shared"
      ]
    }
  
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
  
    precondition (($input.title|strlen) > 0 && ($input.language_code|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: title and language_code are required"
    }
  
    precondition ($input.acquisition_method != "automated_fetch") {
      error_type = "inputerror"
      error = "PHASE_1A: automated_fetch sources are not available until Phase 1B"
    }
  
    precondition ($input.processing_basis_status != "legally_reviewed" || $pc.ctx.rank >= 3) {
      error_type = "accessdenied"
      error = "FORBIDDEN: Only reviewers can record a legally reviewed processing basis"
    }
  
    var $url {
      value = (($input.canonical_url ?? "")|trim|to_lower)
    }
  
    var.update $url {
      value = "/#.*$/"|regex_replace:"":$url
    }
  
    var.update $url {
      value = "~/+$~"|regex_replace:"":$url
    }
  
    var $content_hash {
      value = null
    }
  
    conditional {
      if ((($input.content_text ?? "")|strlen) > 0) {
        var.update $content_hash {
          value = $input.content_text|sha256
        }
      }
    }
  
    security.create_uuid as $manual_id
    var $dedupe_key {
      value = "manual:" ~ $manual_id
    }
  
    conditional {
      if (($url|strlen) > 0) {
        var.update $dedupe_key {
          value = "url:" ~ ($url|sha256)
        }
      }
    
      elseif ($content_hash != null) {
        var.update $dedupe_key {
          value = "content:" ~ $content_hash
        }
      }
    }
  
    db.query research_sources {
      where = $db.research_sources.research_project_id == $input.project_id && $db.research_sources.dedupe_key == $dedupe_key
      return = {type: "single"}
    } as $existing
  
    conditional {
      if ($existing != null) {
        return {
          value = {source: $existing, duplicate: true}
        }
      }
    }
  
    function.run "privacy/pseudonymize" {
      input = {
        organization_id: $pc.project.organization_id
        handle         : $input.author_handle
      }
    } as $author_ref
  
    var $reviewed_by {
      value = null
    }
  
    var $reviewed_at {
      value = null
    }
  
    conditional {
      if ($input.processing_basis_status == "legally_reviewed") {
        var.update $reviewed_by {
          value = $auth.id
        }
      
        var.update $reviewed_at {
          value = now
        }
      }
    }
  
    db.transaction {
      stack {
        db.add research_sources {
          data = {
            created_at                   : now
            organization_id              : $pc.project.organization_id
            research_project_id          : $input.project_id
            source_kind                  : $input.source_kind
            canonical_url                : $input.canonical_url
            title                        : $input.title
            publisher                    : $input.publisher
            author_ref                   : $author_ref
            published_at                 : $input.published_at
            captured_at                  : $input.captured_at ?? now
            language_code                : $input.language_code
            content_text                 : $input.content_text
            content_hash                 : $content_hash
            storage_ref                  : $input.storage_ref
            dedupe_key                   : $dedupe_key
            retrieval_status             : $input.retrieval_status ?? "ok"
            review_status                : "candidate"
            processing_basis_code        : $input.processing_basis_code
            processing_basis_jurisdiction: $input.processing_basis_jurisdiction
            processing_basis_status      : $input.processing_basis_status ?? "undetermined"
            processing_basis_reviewed_by : $reviewed_by
            processing_basis_reviewed_at : $reviewed_at
            privacy_policy_version       : $input.privacy_policy_version
            acquisition_method           : $input.acquisition_method
            access_conditions            : $input.access_conditions
            acquired_by                  : $auth.id
            terms_note                   : $input.terms_note
            usage_rights                 : $input.usage_rights ?? "undetermined"
            usage_rights_basis           : $input.usage_rights_basis
            license_ref                  : $input.license_ref
            personal_data_class          : $input.personal_data_class ?? "undetermined"
            retention_rule_code          : $input.retention_rule_code
            retention_until              : $input.retention_until
            deletion_status              : "active"
            origin                       : "human_entered"
          }
        } as $source
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "research_sources"
            entity_id          : $source.id
            action             : "create"
            to_status          : "candidate"
            after_hash         : $content_hash
          }
        } as $event
      }
    }
  }

  response = {source: $source, duplicate: false}
  guid = "Tn4TTd8Fpo2ZTnQvCed3TNErv4I"
}
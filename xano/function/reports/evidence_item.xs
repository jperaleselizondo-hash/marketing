// Build one evidence entry for a report, applying the fail-closed privacy and rights rules (docs/10 §3).
// The observation/excerpt/source ids are always kept for traceability; only the text may be withheld.
function "reports/evidence_item" {
  input {
    json observation
    json? excerpt?
    json? source?
    text stance
  }

  stack {
    var $obs {
      value = $input.observation
    }
  
    var $exc {
      value = $input.excerpt
    }
  
    var $src {
      value = $input.source
    }
  
    var $usage {
      value = ($exc|get:"usage_rights") ?? (($src|get:"usage_rights") ?? "undetermined")
    }
  
    var $pd {
      value = ($exc|get:"personal_data_class") ?? (($src|get:"personal_data_class") ?? "undetermined")
    }
  
    var $basis {
      value = ($src|get:"processing_basis_status") ?? "undetermined"
    }
  
    var $is_quote {
      value = $obs.observation_type == "verbatim_quote"
    }
  
    var $reason {
      value = null
    }
  
    conditional {
      if (($exc|get:"redaction_status") == "redacted") {
        var.update $reason {
          value = "redacted"
        }
      }
    
      elseif ($usage == "prohibited") {
        var.update $reason {
          value = "usage_prohibited"
        }
      }
    
      elseif ($pd == "special_category") {
        var.update $reason {
          value = "special_category_personal_data"
        }
      }
    
      elseif ($is_quote && (["internal_analysis_only", "quote_anonymized_permitted", "quote_attributed_permitted"]|in:$usage) == false) {
        var.update $reason {
          value = "quotation_not_permitted"
        }
      }
    
      elseif ($is_quote && ["identifiable", "undetermined"]|in:$pd && ["undetermined", "not_applicable"]|in:$basis) {
        var.update $reason {
          value = "personal_data_basis_undetermined"
        }
      }
    }
  
    var $text {
      value = null
    }
  
    conditional {
      if ($reason == null) {
        var.update $text {
          value = $obs.original_text
        }
      }
    }
  
    var $item {
      value = {
        observation_id             : $obs.id
        observation_type           : $obs.observation_type
        stance                     : $input.stance
        provenance_status          : $obs.provenance_status
        origin                     : $obs.origin
        speaker_ref                : $obs.speaker_ref
        speaker_role               : $obs.speaker_role
        language_code              : $obs.language_code
        text                       : $text
        text_withheld_reason       : $reason
        source_excerpt_id          : $obs.source_excerpt_id
        excerpt_hash               : $exc|get:"excerpt_hash"
        excerpt_verification_status: $exc|get:"verification_status"
        source_id                  : $exc|get:"source_id"
      }
    }
  }

  response = $item
  guid = "v13SBo78vl6JmZg_jv4XULKPa40"
}
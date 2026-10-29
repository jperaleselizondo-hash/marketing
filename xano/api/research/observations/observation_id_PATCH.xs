// Edit a candidate observation. Verbatim quote text cannot be edited (it mirrors the excerpt).
// Reviewers may mark provenance as disputed; "verified" is only ever derived from a verified excerpt.
query "observations/{observation_id}" verb=PATCH {
  api_group = "research"
  auth = "user"

  input {
    int observation_id
    int? research_segment_id?
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
  
    enum? provenance_status? {
      values = ["unverified", "disputed"]
    }
  }

  stack {
    db.get research_observations {
      field_name = "id"
      field_value = $input.observation_id
    } as $observation
  
    precondition ($observation != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Observation not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $observation.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ($observation.review_status == "candidate") {
      error_type = "inputerror"
      error = "IMMUTABLE: Only candidate items can be edited; reopen it first"
    }
  
    precondition ($input.original_text == null || $observation.observation_type != "verbatim_quote") {
      error_type = "inputerror"
      error = "IMMUTABLE: Verbatim quote text mirrors its excerpt; supersede the excerpt instead"
    }
  
    precondition ($input.provenance_status == null || $pc.ctx.rank >= 3) {
      error_type = "accessdenied"
      error = "FORBIDDEN: Only reviewers can change provenance status"
    }
  
    precondition ($input.provenance_status != "unverified" || $observation.provenance_status == "disputed") {
      error_type = "inputerror"
      error = "INVALID_TRANSITION: provenance can only be reset to unverified from disputed"
    }
  
    conditional {
      if ($input.research_segment_id != null) {
        db.get research_segments {
          field_name = "id"
          field_value = $input.research_segment_id
        } as $segment
      
        precondition ($segment != null && $segment.research_project_id == $observation.research_project_id) {
          error_type = "notfound"
          error = "NOT_FOUND: Segment not found in this project"
        }
      }
    }
  
    var $updates {
      value = {updated_at: now, revision: ($observation.revision ?? 1) + 1}|set_ifnotnull:"research_segment_id":$input.research_segment_id|set_ifnotnull:"original_text":$input.original_text|set_ifnotnull:"language_code":$input.language_code|set_ifnotnull:"speaker_role":$input.speaker_role|set_ifnotnull:"provenance_status":$input.provenance_status
    }
  
    conditional {
      if ($input.speaker_handle != null) {
        function.run "privacy/pseudonymize" {
          input = {
            organization_id: $observation.organization_id
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
        db.patch research_observations {
          field_name = "id"
          field_value = $observation.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $observation.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $observation.organization_id
            research_project_id: $observation.research_project_id
            actor_id           : $auth.id
            entity_type        : "research_observations"
            entity_id          : $observation.id
            action             : "update"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "7iXq4JowSEr6eDwFucNFly4xYfo"
}
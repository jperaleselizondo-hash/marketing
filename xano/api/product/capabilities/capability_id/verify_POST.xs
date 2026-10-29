// Reviewer decision on a capability. verify requires at least one approved proof (gate R1_PRODUCT_FACTS);
// dispute and unverify require a reason.
query "capabilities/{capability_id}/verify" verb=POST {
  api_group = "product"
  auth = "user"

  input {
    int capability_id
    enum decision {
      values = ["verify", "dispute", "unverify"]
    }
  
    text? reason?
  }

  stack {
    db.get product_capabilities {
      field_name = "id"
      field_value = $input.capability_id
    } as $capability
  
    precondition ($capability != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Capability not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $capability.research_project_id
        min_role  : "reviewer"
        for_write : true
      }
    } as $pc
  
    var $targets {
      value = {
        verify  : "verified"
        dispute : "disputed"
        unverify: "unverified"
      }
    }
  
    var $to {
      value = $targets|get:$input.decision
    }
  
    precondition ($to != $capability.verification_status) {
      error_type = "inputerror"
      error = "INVALID_TRANSITION: capability is already " ~ $capability.verification_status
    }
  
    precondition ($input.decision == "verify" || (($input.reason ?? "")|trim|strlen) > 0) {
      error_type = "inputerror"
      error = "REASON_REQUIRED: dispute and unverify need a reason"
    }
  
    var $gate {
      value = null
    }
  
    conditional {
      if ($input.decision == "verify") {
        db.query product_proofs {
          where = $db.product_proofs.capability_id == $capability.id && $db.product_proofs.review_status == "approved"
          return = {type: "count"}
        } as $approved_proofs
      
        precondition ($approved_proofs > 0) {
          error_type = "inputerror"
          error = "PROOF_REQUIRED: Verification requires at least one approved proof for this capability"
        }
      
        var.update $gate {
          value = "R1_PRODUCT_FACTS"
        }
      }
    }
  
    var $updates {
      value = {
        verification_status: $to
        verified_by        : null
        verified_at        : null
        updated_at         : now
      }
    }
  
    conditional {
      if ($input.decision == "verify") {
        var.update $updates {
          value = $updates
            |set:"verified_by":$auth.id
            |set:"verified_at":now
        }
      }
    }
  
    db.transaction {
      stack {
        db.patch product_capabilities {
          field_name = "id"
          field_value = $capability.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $capability.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $capability.organization_id
            research_project_id: $capability.research_project_id
            actor_id           : $auth.id
            entity_type        : "product_capabilities"
            entity_id          : $capability.id
            action             : $input.decision
            gate_code          : $gate
            from_status        : $capability.verification_status
            to_status          : $to
            reason             : $input.reason
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "fPoO9akCGt9AELUWB6Gl841Fmuo"
}
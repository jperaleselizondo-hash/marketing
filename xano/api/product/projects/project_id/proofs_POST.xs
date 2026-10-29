// Record proof for a capability and/or benefit: a verified source excerpt or a documented owner attestation.
query "projects/{project_id}/proofs" verb=POST {
  api_group = "product"
  auth = "user"

  input {
    int project_id
    int? capability_id?
    int? benefit_id?
    enum proof_type {
      values = ["source_excerpt", "owner_attestation"]
    }
  
    int? source_excerpt_id?
    text? owner_attestation_text?
    text? note?
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
  
    precondition ($input.capability_id != null || $input.benefit_id != null) {
      error_type = "inputerror"
      error = "VALIDATION: capability_id or benefit_id is required"
    }
  
    conditional {
      if ($input.capability_id != null) {
        db.get product_capabilities {
          field_name = "id"
          field_value = $input.capability_id
        } as $capability
      
        precondition ($capability != null && $capability.research_project_id == $input.project_id) {
          error_type = "notfound"
          error = "NOT_FOUND: Capability not found in this project"
        }
      }
    }
  
    conditional {
      if ($input.benefit_id != null) {
        db.get product_benefits {
          field_name = "id"
          field_value = $input.benefit_id
        } as $benefit
      
        precondition ($benefit != null && $benefit.research_project_id == $input.project_id) {
          error_type = "notfound"
          error = "NOT_FOUND: Benefit not found in this project"
        }
      }
    }
  
    var $excerpt_id {
      value = null
    }
  
    var $attestation {
      value = null
    }
  
    var $attested_by {
      value = null
    }
  
    conditional {
      if ($input.proof_type == "source_excerpt") {
        precondition ($input.source_excerpt_id != null) {
          error_type = "inputerror"
          error = "VALIDATION: source_excerpt proofs require source_excerpt_id"
        }
      
        db.get source_excerpts {
          field_name = "id"
          field_value = $input.source_excerpt_id
        } as $excerpt
      
        precondition ($excerpt != null && $excerpt.research_project_id == $input.project_id) {
          error_type = "notfound"
          error = "NOT_FOUND: Excerpt not found in this project"
        }
      
        precondition ($excerpt.verification_status == "verified") {
          error_type = "inputerror"
          error = "EXCERPT_NOT_VERIFIED: Proof excerpts must be verified"
        }
      
        var.update $excerpt_id {
          value = $excerpt.id
        }
      }
    
      else {
        precondition ((($input.owner_attestation_text ?? "")|trim|strlen) > 0) {
          error_type = "inputerror"
          error = "VALIDATION: owner_attestation proofs require owner_attestation_text"
        }
      
        var.update $attestation {
          value = $input.owner_attestation_text
        }
      
        var.update $attested_by {
          value = $auth.id
        }
      }
    }
  
    db.transaction {
      stack {
        db.add product_proofs {
          data = {
            created_at            : now
            organization_id       : $pc.project.organization_id
            research_project_id   : $input.project_id
            capability_id         : $input.capability_id
            benefit_id            : $input.benefit_id
            proof_type            : $input.proof_type
            source_excerpt_id     : $excerpt_id
            owner_attestation_text: $attestation
            attested_by           : $attested_by
            note                  : $input.note
            review_status         : "candidate"
            origin                : "human_entered"
            created_by            : $auth.id
          }
        } as $proof
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "product_proofs"
            entity_id          : $proof.id
            action             : "create"
            to_status          : "candidate"
          }
        } as $event
      }
    }
  }

  response = $proof
  guid = "ojzYp3F4SgHDd86TAPVFFK_dFtk"
}
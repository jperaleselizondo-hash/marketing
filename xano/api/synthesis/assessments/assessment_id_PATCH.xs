query "assessments/{assessment_id}" verb=PATCH {
  api_group = "synthesis"
  auth = "user"

  input {
    int assessment_id
    enum? awareness_level? {
      values = [
        "unaware"
        "problem_aware"
        "solution_aware"
        "product_aware"
        "most_aware"
      ]
    }
  
    int? sophistication_stage?
    json? assessment_json?
    text? rationale?
    enum? evidence_basis? {
      values = ["evidenced", "hypothesis"]
    }
  
    enum? confidence? {
      values = ["low", "medium", "high"]
    }
  }

  stack {
    db.get research_assessments {
      field_name = "id"
      field_value = $input.assessment_id
    } as $assessment
  
    precondition ($assessment != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Assessment not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $assessment.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ($assessment.review_status == "candidate") {
      error_type = "inputerror"
      error = "IMMUTABLE: Only candidate items can be edited; reopen it first"
    }
  
    var $awareness {
      value = $input.awareness_level ?? $assessment.awareness_level
    }
  
    var $stage {
      value = $input.sophistication_stage ?? $assessment.sophistication_stage
    }
  
    precondition (($assessment.assessment_type == "awareness") == ($awareness != null)) {
      error_type = "inputerror"
      error = "VALIDATION: awareness_level is required for, and only for, awareness assessments"
    }
  
    precondition (($assessment.assessment_type == "sophistication") == ($stage != null)) {
      error_type = "inputerror"
      error = "VALIDATION: sophistication_stage is required for, and only for, sophistication assessments"
    }
  
    precondition ($stage == null || ($stage >= 1 && $stage <= 5)) {
      error_type = "inputerror"
      error = "VALIDATION: sophistication_stage must be between 1 and 5"
    }
  
    precondition ($input.rationale == null || ($input.rationale|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: rationale cannot be empty"
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"awareness_level":$input.awareness_level|set_ifnotnull:"sophistication_stage":$input.sophistication_stage|set_ifnotnull:"assessment_json":$input.assessment_json|set_ifnotnull:"rationale":$input.rationale|set_ifnotnull:"evidence_basis":$input.evidence_basis|set_ifnotnull:"confidence":$input.confidence
    }
  
    db.transaction {
      stack {
        db.patch research_assessments {
          field_name = "id"
          field_value = $assessment.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $assessment.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $assessment.organization_id
            research_project_id: $assessment.research_project_id
            actor_id           : $auth.id
            entity_type        : "research_assessments"
            entity_id          : $assessment.id
            action             : "update"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "si-qQi6rlZ3tcetRkhjpruFllTc"
}
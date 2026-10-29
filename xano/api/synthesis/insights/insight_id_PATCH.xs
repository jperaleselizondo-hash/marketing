query "insights/{insight_id}" verb=PATCH {
  api_group = "synthesis"
  auth = "user"

  input {
    int insight_id
    text? statement?
    enum? evidence_basis? {
      values = ["evidenced", "hypothesis"]
    }
  
    enum? confidence? {
      values = ["low", "medium", "high"]
    }
  
    enum? ivoc_category? {
      values = [
        "pain_fear"
        "desire"
        "objection"
        "firm_belief"
        "shakable_belief"
        "vocabulary"
        "other"
      ]
    }
  }

  stack {
    db.get research_insights {
      field_name = "id"
      field_value = $input.insight_id
    } as $insight
  
    precondition ($insight != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Insight not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $insight.research_project_id
        min_role  : "editor"
        for_write : true
      }
    } as $pc
  
    precondition ($insight.status == "candidate") {
      error_type = "inputerror"
      error = "IMMUTABLE: Only candidate items can be edited; reopen it first"
    }
  
    precondition ($input.statement == null || ($input.statement|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: statement cannot be empty"
    }
  
    var $updates {
      value = {updated_at: now, revision: ($insight.revision ?? 1) + 1}|set_ifnotnull:"statement":$input.statement|set_ifnotnull:"evidence_basis":$input.evidence_basis|set_ifnotnull:"confidence":$input.confidence|set_ifnotnull:"ivoc_category":$input.ivoc_category
    }
  
    db.transaction {
      stack {
        db.patch research_insights {
          field_name = "id"
          field_value = $insight.id
          data = $updates
        } as $updated
      
        function.run "research/touch_project" {
          input = {project_id: $insight.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $insight.organization_id
            research_project_id: $insight.research_project_id
            actor_id           : $auth.id
            entity_type        : "research_insights"
            entity_id          : $insight.id
            action             : "update"
            details            : {fields: $updates|keys}
          }
        } as $event
      }
    }
  }

  response = $updated
  guid = "Xkw56QRiJkYm_Dri5N9oVWKSMbY"
}
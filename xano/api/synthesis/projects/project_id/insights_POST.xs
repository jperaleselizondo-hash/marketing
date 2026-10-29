query "projects/{project_id}/insights" verb=POST {
  api_group = "synthesis"
  auth = "user"

  input {
    int project_id
    int research_segment_id
    enum insight_kind {
      values = ["ivoc_theme", "opportunity"]
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
  
    text statement
    enum evidence_basis {
      values = ["evidenced", "hypothesis"]
    }
  
    enum? confidence? {
      values = ["low", "medium", "high"]
    }
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
  
    db.get research_segments {
      field_name = "id"
      field_value = $input.research_segment_id
    } as $segment
  
    precondition ($segment != null && $segment.research_project_id == $input.project_id) {
      error_type = "notfound"
      error = "NOT_FOUND: Segment not found in this project"
    }
  
    precondition (($input.statement|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: statement is required"
    }
  
    precondition ($input.insight_kind != "ivoc_theme" || $input.ivoc_category != null) {
      error_type = "inputerror"
      error = "VALIDATION: ivoc_category is required for ivoc_theme insights"
    }
  
    db.transaction {
      stack {
        db.add research_insights {
          data = {
            created_at         : now
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            research_segment_id: $segment.id
            insight_kind       : $input.insight_kind
            ivoc_category      : $input.ivoc_category
            statement          : $input.statement
            evidence_basis     : $input.evidence_basis
            status             : "candidate"
            confidence         : $input.confidence
            revision           : 1
            origin             : "human_entered"
            created_by         : $auth.id
          }
        } as $insight
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "research_insights"
            entity_id          : $insight.id
            action             : "create"
            to_status          : "candidate"
          }
        } as $event
      }
    }
  }

  response = $insight
  guid = "YzNV9-ZBNTX54FcPu2jzYYE3YMo"
}
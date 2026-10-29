// Link an observation to an insight as supporting or contradicting evidence. Contradicting evidence is kept, never dropped.
query "insights/{insight_id}/support" verb=POST {
  api_group = "synthesis"
  auth = "user"

  input {
    int insight_id
    int observation_id
    enum stance {
      values = ["support", "contradict"]
    }
  
    text? reviewer_note?
    text? cross_segment_note?
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
  
    precondition ($insight.status == "candidate" || $insight.status == "in_review") {
      error_type = "inputerror"
      error = "INSIGHT_LOCKED: Evidence can only be linked to candidate or in-review insights"
    }
  
    db.get research_observations {
      field_name = "id"
      field_value = $input.observation_id
    } as $observation
  
    precondition ($observation != null && $observation.research_project_id == $insight.research_project_id) {
      error_type = "notfound"
      error = "NOT_FOUND: Observation not found in this project"
    }
  
    precondition ($observation.review_status != "rejected") {
      error_type = "inputerror"
      error = "VALIDATION: Rejected observations cannot be used as evidence"
    }
  
    precondition ($observation.research_segment_id == null || $observation.research_segment_id == $insight.research_segment_id || (($input.cross_segment_note ?? "")|strlen) > 0) {
      error_type = "inputerror"
      error = "CROSS_SEGMENT_NOTE_REQUIRED: Observation belongs to another segment; explain the cross-segment use"
    }
  
    db.query insight_support {
      where = $db.insight_support.insight_id == $insight.id && $db.insight_support.observation_id == $observation.id && $db.insight_support.stance == $input.stance
      return = {type: "exists"}
    } as $exists
  
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "DUPLICATE: This evidence link already exists"
    }
  
    db.transaction {
      stack {
        db.add insight_support {
          data = {
            created_at         : now
            organization_id    : $insight.organization_id
            research_project_id: $insight.research_project_id
            insight_id         : $insight.id
            observation_id     : $observation.id
            stance             : $input.stance
            reviewer_note      : $input.reviewer_note
            cross_segment_note : $input.cross_segment_note
            review_status      : "candidate"
            origin             : "human_entered"
            created_by         : $auth.id
          }
        } as $support
      
        function.run "research/touch_project" {
          input = {project_id: $insight.research_project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $insight.organization_id
            research_project_id: $insight.research_project_id
            actor_id           : $auth.id
            entity_type        : "insight_support"
            entity_id          : $support.id
            action             : "create"
            to_status          : "candidate"
          }
        } as $event
      }
    }
  }

  response = $support
  guid = "nlu_K9eW0MLOQ6j0Glpu1nke2lw"
}
// Record an assessment. Awareness and sophistication are always per segment.
query "projects/{project_id}/assessments" verb=POST {
  api_group = "synthesis"
  auth = "user"

  input {
    int project_id
    int? research_segment_id?
    enum assessment_type {
      values = [
        "awareness"
        "sophistication"
        "ideal_client"
        "trust"
        "market_context"
        "competitive_summary"
      ]
    }
  
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
    text rationale
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
  
    var $per_segment {
      value = $input.assessment_type == "awareness" || $input.assessment_type == "sophistication"
    }
  
    precondition ($per_segment == false || $input.research_segment_id != null) {
      error_type = "inputerror"
      error = "VALIDATION: awareness and sophistication assessments require research_segment_id"
    }
  
    conditional {
      if ($input.research_segment_id != null) {
        db.get research_segments {
          field_name = "id"
          field_value = $input.research_segment_id
        } as $segment
      
        precondition ($segment != null && $segment.research_project_id == $input.project_id) {
          error_type = "notfound"
          error = "NOT_FOUND: Segment not found in this project"
        }
      }
    }
  
    precondition (($input.assessment_type == "awareness") == ($input.awareness_level != null)) {
      error_type = "inputerror"
      error = "VALIDATION: awareness_level is required for, and only for, awareness assessments"
    }
  
    precondition (($input.assessment_type == "sophistication") == ($input.sophistication_stage != null)) {
      error_type = "inputerror"
      error = "VALIDATION: sophistication_stage is required for, and only for, sophistication assessments"
    }
  
    precondition ($input.sophistication_stage == null || ($input.sophistication_stage >= 1 && $input.sophistication_stage <= 5)) {
      error_type = "inputerror"
      error = "VALIDATION: sophistication_stage must be between 1 and 5"
    }
  
    precondition (($input.rationale|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: rationale is required"
    }
  
    db.transaction {
      stack {
        db.add research_assessments {
          data = {
            created_at          : now
            organization_id     : $pc.project.organization_id
            research_project_id : $input.project_id
            research_segment_id : $input.research_segment_id
            assessment_type     : $input.assessment_type
            awareness_level     : $input.awareness_level
            sophistication_stage: $input.sophistication_stage
            assessment_json     : $input.assessment_json
            rationale           : $input.rationale
            evidence_basis      : $input.evidence_basis
            confidence          : $input.confidence
            review_status       : "candidate"
            origin              : "human_entered"
            created_by          : $auth.id
          }
        } as $assessment
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "research_assessments"
            entity_id          : $assessment.id
            action             : "create"
            to_status          : "candidate"
          }
        } as $event
      }
    }
  }

  response = $assessment
  guid = "5JoXAIGwa7hJGCo1t-DoUqdRJ_E"
}
// Link a product benefit to an evidenced desire insight of the same segment.
query "projects/{project_id}/benefit-desire-links" verb=POST {
  api_group = "synthesis"
  auth = "user"

  input {
    int project_id
    int research_segment_id
    int benefit_id
    int insight_id
    text rationale
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
  
    db.get product_benefits {
      field_name = "id"
      field_value = $input.benefit_id
    } as $benefit
  
    precondition ($benefit != null && $benefit.research_project_id == $input.project_id) {
      error_type = "notfound"
      error = "NOT_FOUND: Benefit not found in this project"
    }
  
    precondition ($benefit.review_status != "rejected") {
      error_type = "inputerror"
      error = "VALIDATION: Rejected benefits cannot be linked"
    }
  
    db.get research_insights {
      field_name = "id"
      field_value = $input.insight_id
    } as $insight
  
    precondition ($insight != null && $insight.research_project_id == $input.project_id) {
      error_type = "notfound"
      error = "NOT_FOUND: Insight not found in this project"
    }
  
    precondition ($insight.insight_kind == "ivoc_theme" && $insight.ivoc_category == "desire") {
      error_type = "inputerror"
      error = "NOT_A_DESIRE: Benefits can only be linked to desire insights"
    }
  
    precondition ($insight.research_segment_id == $input.research_segment_id) {
      error_type = "inputerror"
      error = "SEGMENT_MISMATCH: Insight belongs to another segment"
    }
  
    precondition ($insight.status != "rejected") {
      error_type = "inputerror"
      error = "VALIDATION: Rejected insights cannot be linked"
    }
  
    precondition (($input.rationale|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: rationale is required"
    }
  
    db.query benefit_desire_links {
      where = $db.benefit_desire_links.benefit_id == $benefit.id && $db.benefit_desire_links.insight_id == $insight.id && $db.benefit_desire_links.research_segment_id == $input.research_segment_id
      return = {type: "exists"}
    } as $exists
  
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "DUPLICATE: This benefit-desire link already exists"
    }
  
    db.transaction {
      stack {
        db.add benefit_desire_links {
          data = {
            created_at         : now
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            research_segment_id: $input.research_segment_id
            benefit_id         : $benefit.id
            insight_id         : $insight.id
            rationale          : $input.rationale
            review_status      : "candidate"
            origin             : "human_entered"
            created_by         : $auth.id
          }
        } as $link
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "benefit_desire_links"
            entity_id          : $link.id
            action             : "create"
            to_status          : "candidate"
          }
        } as $event
      }
    }
  }

  response = $link
  guid = "sK3i4hwC0-e5oLuSu55d16saaMI"
}
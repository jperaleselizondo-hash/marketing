// Upsert the priority ranking of an approved insight within its segment. Evidence counts are computed from
// approved support links, never accepted from the client. Scores are human estimates (1-5), not prevalence.
query "projects/{project_id}/rankings" verb=PUT {
  api_group = "synthesis"
  auth = "user"

  input {
    int project_id
    int research_segment_id
    int insight_id
    int priority_rank filters=min:1
    text? tie_rule?
    int? urgency_score?
    int? intensity_score?
    int? staying_power_score?
    int? scope_score?
    int? sample_denominator? filters=min:0
    text scoring_rubric_version filters=trim
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
  
    db.get research_insights {
      field_name = "id"
      field_value = $input.insight_id
    } as $insight
  
    precondition ($insight != null && $insight.research_project_id == $input.project_id) {
      error_type = "notfound"
      error = "NOT_FOUND: Insight not found in this project"
    }
  
    precondition ($insight.research_segment_id == $input.research_segment_id) {
      error_type = "inputerror"
      error = "SEGMENT_MISMATCH: Insight belongs to another segment"
    }
  
    precondition ($insight.status == "approved") {
      error_type = "inputerror"
      error = "RANKING_REQUIRES_APPROVED_INSIGHT: Only approved insights can be ranked"
    }
  
    var $scores {
      value = [$input.urgency_score, $input.intensity_score, $input.staying_power_score, $input.scope_score]|filter_empty
    }
  
    var $out_of_range {
      value = $scores|filter:($$ < 1 || $$ > 5)
    }
  
    precondition (($out_of_range|count) == 0) {
      error_type = "inputerror"
      error = "VALIDATION: scores must be between 1 and 5"
    }
  
    precondition (($input.scoring_rubric_version|strlen) > 0 && ($input.rationale|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: scoring_rubric_version and rationale are required"
    }
  
    db.query insight_rankings {
      where = $db.insight_rankings.research_project_id == $input.project_id && $db.insight_rankings.research_segment_id == $input.research_segment_id && $db.insight_rankings.insight_id == $input.insight_id
      return = {type: "single"}
    } as $existing
  
    precondition ($existing == null || $existing.review_status == "candidate") {
      error_type = "inputerror"
      error = "IMMUTABLE: Only candidate items can be edited; reopen it first"
    }
  
    db.query insight_rankings {
      where = $db.insight_rankings.research_project_id == $input.project_id && $db.insight_rankings.research_segment_id == $input.research_segment_id && $db.insight_rankings.priority_rank == $input.priority_rank && $db.insight_rankings.insight_id != $input.insight_id
      return = {type: "list"}
    } as $same_rank
  
    var $untied {
      value = $same_rank|filter:((($$.tie_rule ?? "")|strlen) == 0)
    }
  
    precondition (($same_rank|count) == 0 || ((($input.tie_rule ?? "")|strlen) > 0 && ($untied|count) == 0)) {
      error_type = "inputerror"
      error = "DUPLICATE_RANK: Another insight in this segment has the same rank; provide a tie_rule on both"
    }
  
    function.run "synthesis/evidence_counts" {
      input = {insight_id: $insight.id}
    } as $counts
  
    var $data {
      value = {
        priority_rank            : $input.priority_rank
        tie_rule                 : $input.tie_rule
        urgency_score            : $input.urgency_score
        intensity_score          : $input.intensity_score
        staying_power_score      : $input.staying_power_score
        scope_score              : $input.scope_score
        evidence_count           : $counts.evidence_count
        independent_source_count : $counts.independent_source_count
        independent_speaker_count: $counts.independent_speaker_count
        sample_denominator       : $input.sample_denominator
        scoring_rubric_version   : $input.scoring_rubric_version
        rationale                : $input.rationale
      }
    }
  
    var $action {
      value = "create"
    }
  
    conditional {
      if ($existing != null) {
        var.update $action {
          value = "update"
        }
      }
    }
  
    db.transaction {
      stack {
        conditional {
          if ($existing == null) {
            db.add insight_rankings {
              data = {
                created_at               : now
                organization_id          : $pc.project.organization_id
                research_project_id      : $input.project_id
                research_segment_id      : $input.research_segment_id
                insight_id               : $insight.id
                priority_rank            : $input.priority_rank
                tie_rule                 : $input.tie_rule
                urgency_score            : $input.urgency_score
                intensity_score          : $input.intensity_score
                staying_power_score      : $input.staying_power_score
                scope_score              : $input.scope_score
                score_basis              : "human"
                evidence_count           : $counts.evidence_count
                independent_source_count : $counts.independent_source_count
                independent_speaker_count: $counts.independent_speaker_count
                sample_denominator       : $input.sample_denominator
                scoring_rubric_version   : $input.scoring_rubric_version
                rationale                : $input.rationale
                review_status            : "candidate"
                origin                   : "human_entered"
                created_by               : $auth.id
              }
            } as $ranking
          }
        
          else {
            db.patch insight_rankings {
              field_name = "id"
              field_value = $existing.id
              data = $data|set:"updated_at":now
            } as $ranking
          }
        }
      
        function.run "research/touch_project" {
          input = {project_id: $input.project_id}
        } as $revision
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $pc.project.organization_id
            research_project_id: $input.project_id
            actor_id           : $auth.id
            entity_type        : "insight_rankings"
            entity_id          : $ranking.id
            action             : $action
          }
        } as $event
      }
    }
  }

  response = $ranking
  guid = "JeE6ugG5LaHJEji3QZyBQX3ZH-w"
}
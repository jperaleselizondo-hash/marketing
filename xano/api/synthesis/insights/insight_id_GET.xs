// Insight detail with its evidence graph (support/contradict links enriched with the observation), ranking and counts.
query "insights/{insight_id}" verb=GET {
  api_group = "synthesis"
  auth = "user"

  input {
    int insight_id
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
        min_role  : "viewer"
      }
    } as $pc
  
    db.query insight_support {
      join = {
        research_observations: {
          table: "research_observations"
          where: $db.insight_support.observation_id == $db.research_observations.id
        }
      }
    
      where = $db.insight_support.insight_id == $insight.id
      sort = {id: "asc"}
      eval = {
        observation_text               : $db.research_observations.original_text
        observation_type               : $db.research_observations.observation_type
        observation_provenance_status  : $db.research_observations.provenance_status
        observation_review_status      : $db.research_observations.review_status
        observation_source_excerpt_id  : $db.research_observations.source_excerpt_id
        observation_research_segment_id: $db.research_observations.research_segment_id
      }
    
      return = {type: "list"}
    } as $support
  
    db.query insight_rankings {
      where = $db.insight_rankings.insight_id == $insight.id
      return = {type: "single"}
    } as $ranking
  
    function.run "synthesis/evidence_counts" {
      input = {insight_id: $insight.id}
    } as $counts
  }

  response = {
    insight: $insight
    support: $support
    ranking: $ranking
    counts : $counts
  }

  guid = "SLrxNX3HTVWys1GC2nqf7Cj_TsM"
}
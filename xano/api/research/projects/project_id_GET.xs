// Project detail with evidence counts for dashboards.
query "projects/{project_id}" verb=GET {
  api_group = "research"
  auth = "user"

  input {
    int project_id
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "viewer"
      }
    } as $pc
  
    db.query research_segments {
      where = $db.research_segments.research_project_id == $input.project_id
      return = {type: "count"}
    } as $segment_count
  
    db.query research_sources {
      where = $db.research_sources.research_project_id == $input.project_id
      return = {type: "count"}
    } as $source_count
  
    db.query source_excerpts {
      where = $db.source_excerpts.research_project_id == $input.project_id
      return = {type: "count"}
    } as $excerpt_count
  
    db.query research_observations {
      where = $db.research_observations.research_project_id == $input.project_id
      return = {type: "count"}
    } as $observation_count
  
    db.query research_insights {
      where = $db.research_insights.research_project_id == $input.project_id && $db.research_insights.status == "approved"
      return = {type: "count"}
    } as $approved_insight_count
  }

  response = {
    project: $pc.project
    role   : $pc.ctx.role
    counts : {segments: $segment_count, sources: $source_count, excerpts: $excerpt_count, observations: $observation_count, approved_insights: $approved_insight_count}
  }

  guid = "ZaMrW7HTPhorfvbV6kx3aDGjyFQ"
}
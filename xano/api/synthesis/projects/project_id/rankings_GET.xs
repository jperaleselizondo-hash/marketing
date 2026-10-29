query "projects/{project_id}/rankings" verb=GET {
  api_group = "synthesis"
  auth = "user"

  input {
    int project_id
    int? research_segment_id?
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "viewer"
      }
    } as $pc
  
    db.query insight_rankings {
      where = $db.insight_rankings.research_project_id == $input.project_id && $db.insight_rankings.research_segment_id ==? $input.research_segment_id
      sort = {priority_rank: "asc"}
      return = {type: "list"}
    } as $rankings
  }

  response = $rankings
  guid = "duTNDm0tsrA_5r3AU6_yBbFRDLk"
}
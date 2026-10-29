query "projects/{project_id}/segments" verb=GET {
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
      sort = {name: "asc"}
      return = {type: "list"}
    } as $segments
  }

  response = $segments
  guid = "YL8Yac2snfYnl_RNu1L2zNK5fQ0"
}
query "projects/{project_id}/competitors" verb=GET {
  api_group = "competitors"
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
  
    db.query competitors {
      where = $db.competitors.research_project_id == $input.project_id
      sort = {name: "asc"}
      return = {type: "list"}
    } as $competitors
  }

  response = $competitors
  guid = "IA_D3miWeozIgxzZ8Sh2o_hP6FA"
}
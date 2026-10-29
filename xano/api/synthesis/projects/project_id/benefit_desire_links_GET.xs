query "projects/{project_id}/benefit-desire-links" verb=GET {
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
  
    db.query benefit_desire_links {
      where = $db.benefit_desire_links.research_project_id == $input.project_id && $db.benefit_desire_links.research_segment_id ==? $input.research_segment_id
      sort = {id: "asc"}
      return = {type: "list"}
    } as $links
  }

  response = $links
  guid = "Anlkc_HgvNitH57hz36BvlCic6g"
}
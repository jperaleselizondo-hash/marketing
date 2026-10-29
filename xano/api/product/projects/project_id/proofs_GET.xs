query "projects/{project_id}/proofs" verb=GET {
  api_group = "product"
  auth = "user"

  input {
    int project_id
    int? capability_id?
    int? benefit_id?
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "viewer"
      }
    } as $pc
  
    db.query product_proofs {
      where = $db.product_proofs.research_project_id == $input.project_id && $db.product_proofs.capability_id ==? $input.capability_id && $db.product_proofs.benefit_id ==? $input.benefit_id
      sort = {created_at: "asc"}
      return = {type: "list"}
    } as $proofs
  }

  response = $proofs
  guid = "Fdu5sinu4Yjc4H3r35R2tfaIE_Q"
}
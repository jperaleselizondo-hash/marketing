query "projects/{project_id}/benefits" verb=GET {
  api_group = "product"
  auth = "user"

  input {
    int project_id
    enum? review_status? {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "viewer"
      }
    } as $pc
  
    db.query product_benefits {
      where = $db.product_benefits.research_project_id == $input.project_id && $db.product_benefits.review_status ==? $input.review_status
      sort = {created_at: "asc"}
      return = {type: "list"}
    } as $benefits
  }

  response = $benefits
  guid = "SfE8UYVpcfsq4_h7OpLf1We06AM"
}
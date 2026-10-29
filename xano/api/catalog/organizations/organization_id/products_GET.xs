query "organizations/{organization_id}/products" verb=GET {
  api_group = "catalog"
  auth = "user"

  input {
    int organization_id
    int? brand_id?
  }

  stack {
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $input.organization_id
        min_role       : "viewer"
      }
    } as $ctx
  
    db.query products {
      where = $db.products.organization_id == $input.organization_id && $db.products.brand_id ==? $input.brand_id
      sort = {name: "asc"}
      return = {type: "list"}
    } as $products
  }

  response = $products
  guid = "VO9hd0YbtwGOjVf7CdeGA09MfvQ"
}
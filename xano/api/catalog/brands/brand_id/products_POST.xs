query "brands/{brand_id}/products" verb=POST {
  api_group = "catalog"
  auth = "user"

  input {
    int brand_id
    text name filters=trim
    text? description?
    enum lifecycle_status?=concept {
      values = ["concept", "beta", "live", "retired"]
    }
  }

  stack {
    db.get brands {
      field_name = "id"
      field_value = $input.brand_id
    } as $brand
  
    precondition ($brand != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Brand not found"
    }
  
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $brand.organization_id
        min_role       : "editor"
      }
    } as $ctx
  
    precondition (($input.name|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: name is required"
    }
  
    db.query products {
      where = $db.products.brand_id == $brand.id && $db.products.name == $input.name
      return = {type: "exists"}
    } as $exists
  
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "DUPLICATE: A product with this name already exists for the brand"
    }
  
    db.add products {
      data = {
        created_at      : now
        organization_id : $brand.organization_id
        brand_id        : $brand.id
        name            : $input.name
        description     : $input.description
        lifecycle_status: $input.lifecycle_status
      }
    } as $product
  
    function.run "audit/log_event" {
      input = {
        organization_id: $brand.organization_id
        actor_id       : $auth.id
        entity_type    : "products"
        entity_id      : $product.id
        action         : "create"
      }
    } as $event
  }

  response = $product
  guid = "yYsDjWOq-6Fr1ZvpZ0E_9_M6rAs"
}
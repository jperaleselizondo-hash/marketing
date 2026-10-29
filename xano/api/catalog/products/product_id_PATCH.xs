query "products/{product_id}" verb=PATCH {
  api_group = "catalog"
  auth = "user"

  input {
    int product_id
    text? name? filters=trim
    text? description?
    enum? lifecycle_status? {
      values = ["concept", "beta", "live", "retired"]
    }
  }

  stack {
    db.get products {
      field_name = "id"
      field_value = $input.product_id
    } as $product
  
    precondition ($product != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Product not found"
    }
  
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $product.organization_id
        min_role       : "editor"
      }
    } as $ctx
  
    conditional {
      if ($input.name != null && $input.name != $product.name) {
        db.query products {
          where = $db.products.brand_id == $product.brand_id && $db.products.name == $input.name
          return = {type: "exists"}
        } as $exists
      
        precondition ($exists == false && ($input.name|strlen) > 0) {
          error_type = "inputerror"
          error = "DUPLICATE: A product with this name already exists for the brand"
        }
      }
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"name":$input.name|set_ifnotnull:"description":$input.description|set_ifnotnull:"lifecycle_status":$input.lifecycle_status
    }
  
    db.patch products {
      field_name = "id"
      field_value = $product.id
      data = $updates
    } as $updated
  
    function.run "audit/log_event" {
      input = {
        organization_id: $product.organization_id
        actor_id       : $auth.id
        entity_type    : "products"
        entity_id      : $product.id
        action         : "update"
        details        : {fields: $updates|keys}
      }
    } as $event
  }

  response = $updated
  guid = "FvKbZxRbuidouO6Jq5Ftrcif2_g"
}
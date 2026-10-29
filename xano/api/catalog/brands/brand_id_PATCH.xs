query "brands/{brand_id}" verb=PATCH {
  api_group = "catalog"
  auth = "user"

  input {
    int brand_id
    text? name? filters=trim
    text? description?
    text? market?
    text? default_locale? filters=trim
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
  
    conditional {
      if ($input.name != null && $input.name != $brand.name) {
        db.query brands {
          where = $db.brands.organization_id == $brand.organization_id && $db.brands.name == $input.name
          return = {type: "exists"}
        } as $exists
      
        precondition ($exists == false && ($input.name|strlen) > 0) {
          error_type = "inputerror"
          error = "DUPLICATE: A brand with this name already exists"
        }
      }
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"name":$input.name|set_ifnotnull:"description":$input.description|set_ifnotnull:"market":$input.market|set_ifnotnull:"default_locale":$input.default_locale
    }
  
    db.patch brands {
      field_name = "id"
      field_value = $brand.id
      data = $updates
    } as $updated
  
    function.run "audit/log_event" {
      input = {
        organization_id: $brand.organization_id
        actor_id       : $auth.id
        entity_type    : "brands"
        entity_id      : $brand.id
        action         : "update"
        details        : {fields: $updates|keys}
      }
    } as $event
  }

  response = $updated
  guid = "VqROaih0bXcGboDwzxSIzZGfMco"
}
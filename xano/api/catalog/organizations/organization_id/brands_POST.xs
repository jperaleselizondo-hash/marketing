query "organizations/{organization_id}/brands" verb=POST {
  api_group = "catalog"
  auth = "user"

  input {
    int organization_id
    text name filters=trim
    text? description?
    text? market?
    text? default_locale? filters=trim
  }

  stack {
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $input.organization_id
        min_role       : "editor"
      }
    } as $ctx
  
    precondition (($input.name|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: name is required"
    }
  
    db.query brands {
      where = $db.brands.organization_id == $input.organization_id && $db.brands.name == $input.name
      return = {type: "exists"}
    } as $exists
  
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "DUPLICATE: A brand with this name already exists"
    }
  
    db.add brands {
      data = {
        created_at     : now
        organization_id: $input.organization_id
        name           : $input.name
        description    : $input.description
        market         : $input.market
        default_locale : $input.default_locale
      }
    } as $brand
  
    function.run "audit/log_event" {
      input = {
        organization_id: $input.organization_id
        actor_id       : $auth.id
        entity_type    : "brands"
        entity_id      : $brand.id
        action         : "create"
      }
    } as $event
  }

  response = $brand
  guid = "7SV0WKDXn2oC_OPo_lk-4nRqqJ8"
}
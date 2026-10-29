query "organizations/{organization_id}/projects" verb=POST {
  api_group = "research"
  auth = "user"

  input {
    int organization_id
    int product_id
    int methodology_version_id
    text title filters=trim
    text objective
    text? scope?
    text? target_geography?
    text? target_locale? filters=trim
    decimal? ai_budget_usd? filters=min:0
  }

  stack {
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $input.organization_id
        min_role       : "editor"
      }
    } as $ctx
  
    db.get products {
      field_name = "id"
      field_value = $input.product_id
    } as $product
  
    precondition ($product != null && $product.organization_id == $input.organization_id) {
      error_type = "notfound"
      error = "NOT_FOUND: Product not found in this organization"
    }
  
    db.get methodology_versions {
      field_name = "id"
      field_value = $input.methodology_version_id
    } as $methodology
  
    precondition ($methodology != null && $methodology.status == "published") {
      error_type = "inputerror"
      error = "METHODOLOGY_NOT_PUBLISHED: Projects require a published methodology version"
    }
  
    precondition (($input.title|strlen) > 0 && ($input.objective|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: title and objective are required"
    }
  
    db.transaction {
      stack {
        db.add research_projects {
          data = {
            created_at            : now
            organization_id       : $input.organization_id
            product_id            : $product.id
            methodology_version_id: $methodology.id
            owner_id              : $auth.id
            title                 : $input.title
            objective             : $input.objective
            scope                 : $input.scope
            target_geography      : $input.target_geography
            target_locale         : $input.target_locale
            status                : "draft"
            content_revision      : 0
            ai_budget_usd         : $input.ai_budget_usd
          }
        } as $project
      
        function.run "audit/log_event" {
          input = {
            organization_id    : $input.organization_id
            research_project_id: $project.id
            actor_id           : $auth.id
            entity_type        : "research_projects"
            entity_id          : $project.id
            action             : "create"
            to_status          : "draft"
          }
        } as $event
      }
    }
  }

  response = $project
  guid = "GsOPMz8rf4F6ISsGHW8tUoAwKRs"
}
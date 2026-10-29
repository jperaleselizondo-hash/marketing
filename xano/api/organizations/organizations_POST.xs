// Create an organization (platform administrators only). The creator becomes its owner atomically.
query organizations verb=POST {
  api_group = "organizations"
  auth = "user"

  input {
    text name filters=trim
    text slug filters=trim|lower
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $user
  
    precondition ($user.is_platform_admin && $user.status != "suspended") {
      error_type = "accessdenied"
      error = "FORBIDDEN: Only platform administrators can create organizations"
    }
  
    precondition (($input.name|strlen) > 0 && ("/^[a-z0-9][a-z0-9-]{2,63}$/"|regex_matches:$input.slug)) {
      error_type = "inputerror"
      error = "VALIDATION: name is required; slug must be 3-64 chars of a-z, 0-9 and hyphens"
    }
  
    db.has organizations {
      field_name = "slug"
      field_value = $input.slug
    } as $slug_taken
  
    precondition ($slug_taken == false) {
      error_type = "inputerror"
      error = "DUPLICATE: slug is already in use"
    }
  
    db.transaction {
      stack {
        db.add organizations {
          data = {
            created_at: now
            name      : $input.name
            slug      : $input.slug
            status    : "active"
            created_by: $auth.id
          }
        } as $org
      
        db.add organization_members {
          data = {
            created_at     : now
            organization_id: $org.id
            user_id        : $auth.id
            role           : "owner"
            status         : "active"
            added_by       : $auth.id
          }
        } as $membership
      
        function.run "audit/log_event" {
          input = {
            organization_id: $org.id
            actor_id       : $auth.id
            entity_type    : "organizations"
            entity_id      : $org.id
            action         : "create"
          }
        }
      }
    }
  }

  response = {organization: $org, membership: $membership}
  guid = "fb0Uo_wlS1ZkpzZlJRgveSEfd7g"
}
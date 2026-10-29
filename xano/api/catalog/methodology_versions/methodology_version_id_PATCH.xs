// Edit a draft methodology version. Published and retired versions are immutable.
query "methodology-versions/{methodology_version_id}" verb=PATCH {
  api_group = "catalog"
  auth = "user"

  input {
    int methodology_version_id
    text? title? filters=trim
    text? source_url?
    text? source_hash?
    date? reviewed_on?
    text? instructions_ref?
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $user
  
    precondition ($user.is_platform_admin) {
      error_type = "accessdenied"
      error = "FORBIDDEN: Only platform administrators manage methodology versions"
    }
  
    db.get methodology_versions {
      field_name = "id"
      field_value = $input.methodology_version_id
    } as $methodology
  
    precondition ($methodology != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Methodology version not found"
    }
  
    precondition ($methodology.status == "draft") {
      error_type = "inputerror"
      error = "IMMUTABLE: Only draft methodology versions can be edited"
    }
  
    var $updates {
      value = {updated_at: now}|set_ifnotnull:"title":$input.title|set_ifnotnull:"source_url":$input.source_url|set_ifnotnull:"source_hash":$input.source_hash|set_ifnotnull:"reviewed_on":$input.reviewed_on|set_ifnotnull:"instructions_ref":$input.instructions_ref
    }
  
    db.patch methodology_versions {
      field_name = "id"
      field_value = $methodology.id
      data = $updates
    } as $updated
  
    function.run "audit/log_event" {
      input = {
        actor_id   : $auth.id
        entity_type: "methodology_versions"
        entity_id  : $methodology.id
        action     : "update"
        details    : {fields: $updates|keys}
      }
    } as $event
  }

  response = $updated
  guid = "qtdGC1TdDZLHXZtW747P4GMpbj4"
}
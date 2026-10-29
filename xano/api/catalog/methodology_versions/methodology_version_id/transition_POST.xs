// Publish (draft -> published) or retire (published -> retired) a methodology version.
query "methodology-versions/{methodology_version_id}/transition" verb=POST {
  api_group = "catalog"
  auth = "user"

  input {
    int methodology_version_id
    enum to_status {
      values = ["published", "retired"]
    }
  
    text? reason?
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
  
    precondition (($input.to_status == "published" && $methodology.status == "draft") || ($input.to_status == "retired" && $methodology.status == "published")) {
      error_type = "inputerror"
      error = "INVALID_TRANSITION: cannot move from " ~ $methodology.status ~ " to " ~ $input.to_status
    }
  
    var $updates {
      value = {status: $input.to_status, updated_at: now}
    }
  
    conditional {
      if ($input.to_status == "published") {
        var.update $updates {
          value = $updates
            |set:"approved_by":$auth.id
            |set:"approved_at":now
        }
      }
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
        action     : $input.to_status
        from_status: $methodology.status
        to_status  : $input.to_status
        reason     : $input.reason
      }
    } as $event
  }

  response = $updated
  guid = "ka9c_AplQ0ITWqTO8Tv-Eciudbk"
}
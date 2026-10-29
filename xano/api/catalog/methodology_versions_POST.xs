// Register a methodology version as a draft (platform administrators only).
query "methodology-versions" verb=POST {
  api_group = "catalog"
  auth = "user"

  input {
    text key filters=trim|lower
    text version filters=trim
    text title filters=trim
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
  
    precondition (($input.key|strlen) > 0 && ($input.version|strlen) > 0 && ($input.title|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: key, version and title are required"
    }
  
    db.query methodology_versions {
      where = $db.methodology_versions.key == $input.key && $db.methodology_versions.version == $input.version
      return = {type: "exists"}
    } as $exists
  
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "DUPLICATE: This methodology key and version already exist"
    }
  
    db.add methodology_versions {
      data = {
        created_at      : now
        key             : $input.key
        version         : $input.version
        title           : $input.title
        source_url      : $input.source_url
        source_hash     : $input.source_hash
        reviewed_on     : $input.reviewed_on
        instructions_ref: $input.instructions_ref
        status          : "draft"
        created_by      : $auth.id
      }
    } as $methodology
  
    function.run "audit/log_event" {
      input = {
        actor_id   : $auth.id
        entity_type: "methodology_versions"
        entity_id  : $methodology.id
        action     : "create"
        to_status  : "draft"
      }
    } as $event
  }

  response = $methodology
  guid = "ibNEuEXiUtfUTmWiBAc0jVTJ2rE"
}
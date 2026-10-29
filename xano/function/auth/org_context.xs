// Resolve the caller's active membership in an organization and enforce a minimum role.
// Non-members receive notfound so organization existence is not disclosed.
function "auth/org_context" {
  input {
    int user_id
    int organization_id
    text min_role
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $input.user_id
    } as $user
  
    precondition ($user != null && $user.status != "suspended") {
      error_type = "accessdenied"
      error = "ACCOUNT_INACTIVE: Account is not active"
    }
  
    db.get organizations {
      field_name = "id"
      field_value = $input.organization_id
    } as $org
  
    db.query organization_members {
      where = $db.organization_members.organization_id == $input.organization_id && $db.organization_members.user_id == $input.user_id && $db.organization_members.status == "active"
      return = {type: "single"}
    } as $membership
  
    precondition ($org != null && $membership != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Organization not found"
    }
  
    precondition ($org.status == "active") {
      error_type = "accessdenied"
      error = "ORGANIZATION_ARCHIVED: Organization is archived"
    }
  
    var $ranks {
      value = {viewer: 1, editor: 2, reviewer: 3, owner: 4}
    }
  
    var $have {
      value = $ranks|get:$membership.role:0
    }
  
    var $need {
      value = $ranks|get:$input.min_role:99
    }
  
    precondition ($have >= $need) {
      error_type = "accessdenied"
      error = "FORBIDDEN: Requires organization role " ~ $input.min_role
    }
  }

  response = {
    organization     : $org
    membership       : $membership
    role             : $membership.role
    rank             : $have
    user_id          : $user.id
    is_platform_admin: $user.is_platform_admin
  }

  guid = "A11LLHw2oKdmtx5Qj0CZ3V5zfz8"
}
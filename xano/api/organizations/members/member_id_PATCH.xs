// Change a member's role or remove them (owners only). The last active owner cannot be demoted or removed.
query "members/{member_id}" verb=PATCH {
  api_group = "organizations"
  auth = "user"

  input {
    int member_id
    enum role? {
      values = ["owner", "editor", "reviewer", "viewer"]
    }
  
    enum status? {
      values = ["active", "removed"]
    }
  
    text? reason?
  }

  stack {
    db.get organization_members {
      field_name = "id"
      field_value = $input.member_id
    } as $member
  
    precondition ($member != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Member not found"
    }
  
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $member.organization_id
        min_role       : "owner"
      }
    } as $ctx
  
    var $new_role {
      value = $input.role ?? $member.role
    }
  
    var $new_status {
      value = $input.status ?? $member.status
    }
  
    conditional {
      if ($member.role == "owner" && ($new_role != "owner" || $new_status != "active")) {
        db.query organization_members {
          where = $db.organization_members.organization_id == $member.organization_id && $db.organization_members.role == "owner" && $db.organization_members.status == "active"
          return = {type: "count"}
        } as $owner_count
      
        precondition ($owner_count > 1) {
          error_type = "inputerror"
          error = "LAST_OWNER: An organization must keep at least one active owner"
        }
      }
    }
  
    db.edit organization_members {
      field_name = "id"
      field_value = $member.id
      data = {role: $new_role, status: $new_status, updated_at: now}
    } as $updated
  
    function.run "audit/log_event" {
      input = {
        organization_id: $member.organization_id
        actor_id       : $auth.id
        entity_type    : "organization_members"
        entity_id      : $member.id
        action         : "update"
        from_status    : $member.role ~ "/" ~ $member.status
        to_status      : $new_role ~ "/" ~ $new_status
        reason         : $input.reason
      }
    }
  }

  response = $updated
  guid = "4r64z1ImiBVtCvguMRAA6uw4xd0"
}
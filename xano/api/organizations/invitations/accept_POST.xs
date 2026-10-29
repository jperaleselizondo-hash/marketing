// Accept an invitation with an existing, signed-in account. The account email must match the invitation.
query "invitations/accept" verb=POST {
  api_group = "organizations"
  auth = "user"

  input {
    text token filters=trim
  }

  stack {
    function.run "auth/rate_limit" {
      input = {
        bucket_key    : "accept_invite:user:" ~ $auth.id
        max_attempts  : 10
        window_seconds: 3600
      }
    } as $attempts
  
    db.get invitations {
      field_name = "token_hash"
      field_value = $input.token|sha256
    } as $invitation
  
    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $user
  
    precondition ($invitation != null && $invitation.status == "pending" && $invitation.expires_at > now && $invitation.email == $user.email) {
      error_type = "accessdenied"
      error = "INVALID_INVITATION: Invitation is invalid, expired or addressed to another email"
    }
  
    db.query organization_members {
      where = $db.organization_members.organization_id == $invitation.organization_id && $db.organization_members.user_id == $auth.id
      return = {type: "single"}
    } as $existing_membership
  
    precondition ($existing_membership == null || $existing_membership.status != "active") {
      error_type = "inputerror"
      error = "ALREADY_MEMBER: You are already a member"
    }
  
    db.transaction {
      stack {
        conditional {
          if ($existing_membership == null) {
            db.add organization_members {
              data = {
                created_at     : now
                organization_id: $invitation.organization_id
                user_id        : $auth.id
                role           : $invitation.role
                status         : "active"
                added_by       : $invitation.invited_by
              }
            }
          }
        
          else {
            db.edit organization_members {
              field_name = "id"
              field_value = $existing_membership.id
              data = {
                role      : $invitation.role
                status    : "active"
                updated_at: now
              }
            }
          }
        }
      
        db.edit invitations {
          field_name = "id"
          field_value = $invitation.id
          data = {
            status     : "accepted"
            accepted_by: $auth.id
            accepted_at: now
            updated_at : now
          }
        }
      
        function.run "audit/log_event" {
          input = {
            organization_id: $invitation.organization_id
            actor_id       : $auth.id
            entity_type    : "invitations"
            entity_id      : $invitation.id
            action         : "accept"
            from_status    : "pending"
            to_status      : "accepted"
          }
        }
      }
    }
  }

  response = {
    success        : true
    organization_id: $invitation.organization_id
    role           : $invitation.role
  }

  guid = "HnhgehSNd6IH_1yp0H4_0cZQw2A"
}
// Invite-only registration: create an account from a pending invitation token and join its organization.
// Existing accounts must sign in and use POST invitations/accept instead.
query "auth/accept-invite" verb=POST {
  api_group = "Authentication"

  input {
    text token filters=trim
    text name filters=trim
    text password
  }

  stack {
    function.run "auth/rate_limit" {
      input = {
        bucket_key    : "accept_invite:ip:" ~ $env.$remote_ip
        max_attempts  : 10
        window_seconds: 3600
      }
    } as $attempts
  
    db.get invitations {
      field_name = "token_hash"
      field_value = $input.token|sha256
    } as $invitation
  
    precondition ($invitation != null && $invitation.status == "pending" && $invitation.expires_at > now) {
      error_type = "accessdenied"
      error = "INVALID_INVITATION: Invitation is invalid or expired"
    }
  
    precondition (($input.name|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: name is required"
    }
  
    precondition (($input.password|strlen) >= 12) {
      error_type = "inputerror"
      error = "WEAK_PASSWORD: Password must be at least 12 characters"
    }
  
    db.get user {
      field_name = "email"
      field_value = $invitation.email
    } as $existing
  
    precondition ($existing == null) {
      error_type = "inputerror"
      error = "ACCOUNT_EXISTS: Sign in and accept the invitation from your account"
    }
  
    db.transaction {
      stack {
        db.add user {
          data = {
            created_at       : now
            name             : $input.name
            email            : $invitation.email
            password         : $input.password
            status           : "active"
            is_platform_admin: false
          }
        } as $user
      
        db.add organization_members {
          data = {
            created_at     : now
            organization_id: $invitation.organization_id
            user_id        : $user.id
            role           : $invitation.role
            status         : "active"
            added_by       : $invitation.invited_by
          }
        } as $membership
      
        db.edit invitations {
          field_name = "id"
          field_value = $invitation.id
          data = {
            status     : "accepted"
            accepted_by: $user.id
            accepted_at: now
            updated_at : now
          }
        }
      
        function.run "audit/log_event" {
          input = {
            organization_id: $invitation.organization_id
            actor_id       : $user.id
            entity_type    : "invitations"
            entity_id      : $invitation.id
            action         : "accept"
            from_status    : "pending"
            to_status      : "accepted"
          }
        }
      }
    }
  
    security.create_auth_token {
      table = "user"
      extras = {}
      expiration = 28800
      id = $user.id
    } as $authToken
  }

  response = {authToken: $authToken}
  guid = "_Z22ILlAfk04l2sx3Xt7nSYhkkI"
}
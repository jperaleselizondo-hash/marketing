// Invite someone to an organization (owners only). Returns the plaintext token once; only its sha256 is stored.
// A new invitation for the same email revokes any earlier pending one.
query "organizations/{organization_id}/invitations" verb=POST {
  api_group = "organizations"
  auth = "user"

  input {
    int organization_id
    email email filters=trim|lower
    enum role {
      values = ["editor", "reviewer", "viewer"]
    }
  }

  stack {
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $input.organization_id
        min_role       : "owner"
      }
    } as $ctx
  
    db.get user {
      field_name = "email"
      field_value = $input.email
    } as $invitee
  
    conditional {
      if ($invitee != null) {
        db.query organization_members {
          where = $db.organization_members.organization_id == $input.organization_id && $db.organization_members.user_id == $invitee.id && $db.organization_members.status == "active"
          return = {type: "exists"}
        } as $already_member
      
        precondition ($already_member == false) {
          error_type = "inputerror"
          error = "ALREADY_MEMBER: This person is already a member"
        }
      }
    }
  
    security.create_uuid as $uuid_a
    security.create_uuid as $uuid_b
    var $token {
      value = ($uuid_a ~ $uuid_b)|replace:"-":""
    }
  
    db.query invitations {
      where = $db.invitations.organization_id == $input.organization_id && $db.invitations.email == $input.email && $db.invitations.status == "pending"
      return = {type: "list"}
    } as $previous
  
    db.transaction {
      stack {
        foreach ($previous) {
          each as $old {
            db.edit invitations {
              field_name = "id"
              field_value = $old.id
              data = {status: "revoked", updated_at: now}
            }
          }
        }
      
        db.add invitations {
          data = {
            created_at     : now
            organization_id: $input.organization_id
            email          : $input.email
            role           : $input.role
            token_hash     : $token|sha256
            expires_at     : now|transform_timestamp:"+72 hours"
            status         : "pending"
            invited_by     : $auth.id
          }
        } as $invitation
      
        function.run "audit/log_event" {
          input = {
            organization_id: $input.organization_id
            actor_id       : $auth.id
            entity_type    : "invitations"
            entity_id      : $invitation.id
            action         : "create"
            to_status      : "pending"
          }
        }
      }
    }
  }

  response = {
    invitation: $invitation|unset:"token_hash"
    token     : $token
  }

  guid = "qU_J-NS382xGMR0BYq7JC4Wd5OA"
}
query "invitations/{invitation_id}/revoke" verb=POST {
  api_group = "organizations"
  auth = "user"

  input {
    int invitation_id
  }

  stack {
    db.get invitations {
      field_name = "id"
      field_value = $input.invitation_id
    } as $invitation
  
    precondition ($invitation != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Invitation not found"
    }
  
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $invitation.organization_id
        min_role       : "owner"
      }
    } as $ctx
  
    precondition ($invitation.status == "pending") {
      error_type = "inputerror"
      error = "INVALID_TRANSITION: Only pending invitations can be revoked"
    }
  
    db.edit invitations {
      field_name = "id"
      field_value = $invitation.id
      data = {status: "revoked", updated_at: now}
    }
  
    function.run "audit/log_event" {
      input = {
        organization_id: $invitation.organization_id
        actor_id       : $auth.id
        entity_type    : "invitations"
        entity_id      : $invitation.id
        action         : "revoke"
        from_status    : "pending"
        to_status      : "revoked"
      }
    }
  }

  response = {success: true}
  guid = "OTbzdQv5enPQQiKvSlGN3xZU2GY"
}
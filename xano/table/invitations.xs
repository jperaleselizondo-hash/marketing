table invitations {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?
    int organization_id {
      table = "organizations"
    }
  
    email email filters=trim|lower
    enum role {
      values = ["editor", "reviewer", "viewer"]
    }
  
    text token_hash
    timestamp expires_at
    enum status?=pending {
      values = ["pending", "accepted", "revoked", "expired"]
    }
  
    int invited_by {
      table = "user"
    }
  
    int? accepted_by? {
      table = "user"
    }
  
    timestamp? accepted_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "token_hash"}]}
    {
      type : "btree"
      field: [{name: "organization_id"}, {name: "email"}, {name: "status"}]
    }
  ]

  guid = "nVNYkznLZ36Z-_rh8odlVpursIU"
}
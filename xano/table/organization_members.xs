table organization_members {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?
    int organization_id {
      table = "organizations"
    }
  
    int user_id {
      table = "user"
    }
  
    enum role {
      values = ["owner", "editor", "reviewer", "viewer"]
    }
  
    enum status?=active {
      values = ["active", "removed"]
    }
  
    int? added_by? {
      table = "user"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "organization_id"}, {name: "user_id"}]
    }
    {type: "btree", field: [{name: "user_id"}]}
  ]

  guid = "lDIOJKb5ZWcIzebdMos5PALsj0k"
}
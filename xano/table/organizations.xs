table organizations {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?
    text name filters=trim
    text slug filters=trim|lower
    enum status?=active {
      values = ["active", "archived"]
    }
  
    int created_by {
      table = "user"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "slug"}]}
  ]

  guid = "jYL8Z4qfsroLXeFZvmNBWVw93K0"
}
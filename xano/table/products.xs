table products {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?
    int organization_id {
      table = "organizations"
    }
  
    int brand_id {
      table = "brands"
    }
  
    text name filters=trim
    text? description?
    enum lifecycle_status?=concept {
      values = ["concept", "beta", "live", "retired"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "brand_id"}, {name: "name"}]
    }
    {type: "btree", field: [{name: "organization_id"}]}
  ]

  guid = "KslSxI1qhkbNGG-Y7VVw_zOUaPQ"
}
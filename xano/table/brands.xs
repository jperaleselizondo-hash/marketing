table brands {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?
    int organization_id {
      table = "organizations"
    }
  
    text name filters=trim
    text? description?
    text? market?
    text? default_locale? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "organization_id"}, {name: "name"}]
    }
  ]

  guid = "xOhfmYucrkAYyY8NqM8NcSkaFIE"
}
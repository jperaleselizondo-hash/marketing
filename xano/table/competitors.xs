table competitors {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?
    int organization_id {
      table = "organizations"
    }
  
    int research_project_id {
      table = "research_projects"
    }
  
    text name filters=trim
    text normalized_name
    text? website?
    enum alternative_type {
      values = ["direct", "indirect", "substitute"]
    }
  
    text? positioning_summary?
    enum review_status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    int created_by {
      table = "user"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "research_project_id"}, {name: "normalized_name"}]
    }
    {type: "btree", field: [{name: "organization_id"}]}
  ]

  guid = "w0S03Czz2IpSxeIkakQ7x7xh7Kg"
}
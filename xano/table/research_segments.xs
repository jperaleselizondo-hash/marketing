table research_segments {
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
    enum segment_type {
      values = ["buyer", "supplier", "end_user", "influencer", "other"]
    }
  
    text? geography?
    text? locale?
    text? description?
    enum? awareness_hypothesis? {
      values = [
        "unaware"
        "problem_aware"
        "solution_aware"
        "product_aware"
        "most_aware"
      ]
    }
  
    int created_by {
      table = "user"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "research_project_id"}, {name: "name"}]
    }
    {type: "btree", field: [{name: "organization_id"}]}
  ]

  guid = "ACV17sSjLd5qbxySwGpfsYgYJhM"
}
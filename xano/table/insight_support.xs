table insight_support {
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
  
    int insight_id {
      table = "research_insights"
    }
  
    int observation_id {
      table = "research_observations"
    }
  
    enum stance {
      values = ["support", "contradict"]
    }
  
    text? reviewer_note?
    text? cross_segment_note?
    enum review_status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    int? reviewer_id? {
      table = "user"
    }
  
    enum origin?=human_entered {
      values = ["human_entered", "imported", "ai_proposed"]
    }
  
    int created_by {
      table = "user"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "insight_id"}
        {name: "observation_id"}
        {name: "stance"}
      ]
    }
    {type: "btree", field: [{name: "observation_id"}]}
    {type: "btree", field: [{name: "research_project_id"}]}
  ]

  guid = "TiaoFfdW6ByAt6rG1kSfrIP_iCs"
}
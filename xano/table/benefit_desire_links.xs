table benefit_desire_links {
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
  
    int research_segment_id {
      table = "research_segments"
    }
  
    int benefit_id {
      table = "product_benefits"
    }
  
    int insight_id {
      table = "research_insights"
    }
  
    text rationale
    enum review_status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
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
        {name: "benefit_id"}
        {name: "insight_id"}
        {name: "research_segment_id"}
      ]
    }
    {type: "btree", field: [{name: "research_project_id"}]}
  ]

  guid = "6CmwjlAMSV4RbqHyw2wSjQr9T8c"
}
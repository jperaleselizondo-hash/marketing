table capability_benefit_links {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int organization_id {
      table = "organizations"
    }
  
    int research_project_id {
      table = "research_projects"
    }
  
    int capability_id {
      table = "product_capabilities"
    }
  
    int benefit_id {
      table = "product_benefits"
    }
  
    text? rationale?
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
      field: [{name: "capability_id"}, {name: "benefit_id"}]
    }
    {type: "btree", field: [{name: "research_project_id"}]}
  ]

  guid = "3M14waiZOdqOCtHWQR2GmH0zdTE"
}
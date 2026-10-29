table product_benefits {
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
  
    text benefit_text
    enum benefit_type {
      values = ["functional", "emotional", "economic", "social", "other"]
    }
  
    enum review_status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    enum origin?=human_entered {
      values = ["human_entered", "imported", "ai_proposed"]
    }
  
    int? generated_by_job_id? {
      table = "jobs"
    }
  
    int? accepted_by? {
      table = "user"
    }
  
    timestamp? accepted_at?
    int created_by {
      table = "user"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "research_project_id"}]}
    {type: "btree", field: [{name: "organization_id"}]}
  ]

  guid = "FwklDwCYttYYuPujgAK2g2NJQxY"
}
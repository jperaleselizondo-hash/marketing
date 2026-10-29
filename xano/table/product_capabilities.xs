table product_capabilities {
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
  
    int product_id {
      table = "products"
    }
  
    enum capability_type {
      values = ["feature", "service", "performance", "limitation"]
    }
  
    text description
    enum availability_status {
      values = ["live", "beta", "roadmap", "discontinued"]
    }
  
    enum verification_status?=unverified {
      values = ["unverified", "verified", "disputed"]
    }
  
    int? verified_by? {
      table = "user"
    }
  
    timestamp? verified_at?
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

  guid = "yjJpsxx3oIpB71Utf2LBzkvqsIc"
}
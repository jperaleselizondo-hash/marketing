table product_proofs {
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
  
    int? capability_id? {
      table = "product_capabilities"
    }
  
    int? benefit_id? {
      table = "product_benefits"
    }
  
    enum proof_type {
      values = ["source_excerpt", "owner_attestation"]
    }
  
    int? source_excerpt_id? {
      table = "source_excerpts"
    }
  
    text? owner_attestation_text?
    int? attested_by? {
      table = "user"
    }
  
    text? note?
    enum review_status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    int? reviewed_by? {
      table = "user"
    }
  
    timestamp? reviewed_at?
    enum origin?=human_entered {
      values = ["human_entered", "imported", "ai_proposed"]
    }
  
    int created_by {
      table = "user"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "research_project_id"}]}
    {type: "btree", field: [{name: "capability_id"}]}
    {type: "btree", field: [{name: "benefit_id"}]}
  ]

  guid = "H4YNbaR4Ior5cpD6konKcUfGbeg"
}
table competitor_observations {
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
  
    int competitor_id {
      table = "competitors"
    }
  
    enum dimension {
      values = [
        "idea"
        "usp"
        "pain_focus"
        "desire_focus"
        "social_media"
        "ads"
        "praise"
        "complaint"
      ]
    }
  
    text observed_claim
    text? analyst_note?
    int? source_excerpt_id? {
      table = "source_excerpts"
    }
  
    int? observation_id? {
      table = "research_observations"
    }
  
    timestamp? observed_on?
    enum provenance_status?=unverified {
      values = ["verified", "unverified", "disputed"]
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
    {
      type : "btree"
      field: [{name: "competitor_id"}, {name: "dimension"}]
    }
    {type: "btree", field: [{name: "research_project_id"}]}
  ]

  guid = "IQkot2OZgjqkKYNE0TfzceAc5Uc"
}
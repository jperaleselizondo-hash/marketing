table research_assessments {
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
  
    int? research_segment_id? {
      table = "research_segments"
    }
  
    enum assessment_type {
      values = [
        "awareness"
        "sophistication"
        "ideal_client"
        "trust"
        "market_context"
        "competitive_summary"
      ]
    }
  
    enum? awareness_level? {
      values = [
        "unaware"
        "problem_aware"
        "solution_aware"
        "product_aware"
        "most_aware"
      ]
    }
  
    int? sophistication_stage?
    json? assessment_json?
    text rationale
    enum evidence_basis {
      values = ["evidenced", "hypothesis"]
    }
  
    enum? confidence? {
      values = ["low", "medium", "high"]
    }
  
    enum review_status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    int? reviewer_id? {
      table = "user"
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
      field: [
        {name: "research_project_id"}
        {name: "research_segment_id"}
        {name: "assessment_type"}
      ]
    }
  ]

  guid = "87QMpmogj7Z7--hSUmBbK4bIfBA"
}
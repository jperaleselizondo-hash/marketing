table research_insights {
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
  
    enum insight_kind {
      values = ["ivoc_theme", "opportunity"]
    }
  
    enum? ivoc_category? {
      values = [
        "pain_fear"
        "desire"
        "objection"
        "firm_belief"
        "shakable_belief"
        "vocabulary"
        "other"
      ]
    }
  
    text statement
    enum evidence_basis {
      values = ["evidenced", "hypothesis"]
    }
  
    enum status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    enum? confidence? {
      values = ["low", "medium", "high"]
    }
  
    int? reviewer_id? {
      table = "user"
    }
  
    timestamp? reviewed_at?
    int revision?=1
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
        {name: "status"}
      ]
    }
    {type: "btree", field: [{name: "organization_id"}]}
  ]

  guid = "Sj51ax_Nl1lywN7iWO-Mb2__uIE"
}
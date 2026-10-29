table research_observations {
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
  
    int? source_excerpt_id? {
      table = "source_excerpts"
    }
  
    enum observation_type {
      values = [
        "verbatim_quote"
        "paraphrase"
        "secondary_summary"
        "analyst_hypothesis"
      ]
    }
  
    text original_text
    text language_code filters=trim|lower
    text? speaker_ref?
    enum? speaker_role? {
      values = [
        "buyer"
        "supplier"
        "prospect"
        "customer"
        "competitor"
        "expert"
        "owner"
        "unknown"
      ]
    }
  
    enum provenance_status?=unverified {
      values = ["verified", "unverified", "disputed"]
    }
  
    enum review_status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
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
      field: [{name: "research_project_id"}, {name: "research_segment_id"}]
    }
    {type: "btree", field: [{name: "source_excerpt_id"}]}
    {type: "btree", field: [{name: "organization_id"}]}
  ]

  guid = "mOsgkKPYj5rHOBhQ8w3MvZ7-tfQ"
}
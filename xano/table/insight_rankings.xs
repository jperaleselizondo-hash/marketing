table insight_rankings {
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
  
    int insight_id {
      table = "research_insights"
    }
  
    int priority_rank
    text? tie_rule?
    int? urgency_score?
    int? intensity_score?
    int? staying_power_score?
    int? scope_score?
    enum score_basis?=human {
      values = ["human", "ai_proposed"]
    }
  
    int evidence_count?
    int independent_source_count?
    int independent_speaker_count?
    int? sample_denominator?
    text scoring_rubric_version
    text rationale
    enum review_status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    int? reviewed_by? {
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
        {name: "research_project_id"}
        {name: "research_segment_id"}
        {name: "insight_id"}
      ]
    }
    {
      type : "btree"
      field: [
        {name: "research_project_id"}
        {name: "research_segment_id"}
        {name: "priority_rank"}
      ]
    }
  ]

  guid = "FcJWs4oBLItHWaRTFixAtS3U57U"
}
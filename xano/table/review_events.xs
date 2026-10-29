table review_events {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int? organization_id? {
      table = "organizations"
    }
  
    int? research_project_id? {
      table = "research_projects"
    }
  
    int actor_id {
      table = "user"
    }
  
    text entity_type
    int entity_id
    text action
    enum? gate_code? {
      values = [
        "R0_SCOPE"
        "R1_PRODUCT_FACTS"
        "R2_COMPETITORS"
        "R3_EVIDENCE"
        "R4_INSIGHTS"
        "R5_REPORT"
        "S1_DESIRE_MATCH"
        "S2_BIG_IDEA"
        "P1_NARRATIVE"
        "P2_ASSET_REVIEW"
        "P3_PACKAGE"
      ]
    }
  
    text? from_status?
    text? to_status?
    text? reason?
    text? before_hash?
    text? after_hash?
    json? details?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [
        {name: "organization_id"}
        {name: "entity_type"}
        {name: "entity_id"}
      ]
    }
    {type: "btree", field: [{name: "research_project_id"}]}
  ]

  guid = "cR33CdAim3Q4Gzj0x8cxRU8pjFE"
}
table observation_categories {
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
  
    int observation_id {
      table = "research_observations"
    }
  
    enum ivoc_category {
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
  
    enum? confidence? {
      values = ["low", "medium", "high"]
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
      field: [{name: "observation_id"}, {name: "ivoc_category"}]
    }
    {
      type : "btree"
      field: [{name: "research_project_id"}, {name: "ivoc_category"}]
    }
  ]

  guid = "XMdkLpQ4aDOt8kGaii_HOVsxU8g"
}
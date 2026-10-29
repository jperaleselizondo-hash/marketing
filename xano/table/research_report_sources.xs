table research_report_sources {
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
  
    int report_id {
      table = "research_reports"
    }
  
    int source_id {
      table = "research_sources"
    }
  
    text? content_hash_at_approval?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "report_id"}, {name: "source_id"}]
    }
    {type: "btree", field: [{name: "source_id"}]}
  ]

  guid = "C5kDcyb2A_iGgoipoY61T7Ijhl8"
}
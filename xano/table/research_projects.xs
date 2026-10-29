table research_projects {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?
    int organization_id {
      table = "organizations"
    }
  
    int product_id {
      table = "products"
    }
  
    int methodology_version_id {
      table = "methodology_versions"
    }
  
    int owner_id {
      table = "user"
    }
  
    text title filters=trim
    text objective
    text? scope?
    text? target_geography?
    text? target_locale?
    enum status?=draft {
      values = ["draft", "scoped", "collecting", "synthesizing", "archived"]
    }
  
    int content_revision?
    int? current_report_id? {
      table = "research_reports"
    }
  
    decimal? ai_budget_usd?
    timestamp? deleted_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "organization_id"}, {name: "status"}]
    }
    {type: "btree", field: [{name: "product_id"}]}
  ]

  guid = "Mlor-1Pc8ihMvZ-_J_SAyFmo82c"
}
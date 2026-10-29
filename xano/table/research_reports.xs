table research_reports {
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
  
    int version_no
    enum status?=draft {
      values = ["draft", "in_review", "approved", "superseded"]
    }
  
    text schema_version
    json report_json
    text? report_markdown?
    text report_json_hash
    text source_manifest_hash
    int based_on_revision
    int methodology_version_id {
      table = "methodology_versions"
    }
  
    int? generated_job_id? {
      table = "jobs"
    }
  
    int generated_by {
      table = "user"
    }
  
    int? submitted_by? {
      table = "user"
    }
  
    timestamp? submitted_at?
    int? approved_by? {
      table = "user"
    }
  
    timestamp? approved_at?
    text? rejection_reason?
    text? approved_json_hash?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "research_project_id"}, {name: "version_no"}]
    }
    {type: "btree", field: [{name: "organization_id"}]}
  ]

  guid = "SuVJmiFPVgCuvcL4kAZIUjsFAiE"
}
table jobs {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?
    int organization_id {
      table = "organizations"
    }
  
    int? research_project_id? {
      table = "research_projects"
    }
  
    enum job_type {
      values = ["report_render", "ai_extraction", "import", "source_fetch"]
    }
  
    enum status?=pending {
      values = [
        "pending"
        "running"
        "succeeded"
        "failed_retryable"
        "failed_final"
        "cancelled"
      ]
    }
  
    text idempotency_key
    text? input_hash?
    json? input_ref?
    json? output_json?
    text? output_schema_version?
    json? validation_errors?
    text? prompt_version?
    text? model_id?
    int attempt_count?
    int max_attempts?=3
    timestamp? next_attempt_at?
    text? lease_owner?
    timestamp? lease_expires_at?
    decimal? cost_usd?
    int? input_tokens?
    int? output_tokens?
    text? error_code?
    text? error_message?
    timestamp? started_at?
    timestamp? finished_at?
    int created_by {
      table = "user"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "organization_id"}, {name: "idempotency_key"}]
    }
    {type: "btree", field: [{name: "research_project_id"}]}
    {type: "btree", field: [{name: "status"}]}
  ]

  guid = "SDsStvtAASuaDfIjre6uoo3Dtk4"
}
table source_excerpts {
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
  
    int source_id {
      table = "research_sources"
    }
  
    text exact_text
    text? locator?
    timestamp captured_at
    text language_code filters=trim|lower
    text excerpt_hash
    enum verification_status?=pending {
      values = ["pending", "verified", "failed", "pending_human"]
    }
  
    enum? verification_method? {
      values = ["content_match", "human_review"]
    }
  
    int? verified_by? {
      table = "user"
    }
  
    timestamp? verified_at?
    int? supersedes_excerpt_id? {
      table = "source_excerpts"
    }
  
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
  
    enum? usage_rights? {
      values = [
        "internal_analysis_only"
        "paraphrase_permitted"
        "quote_anonymized_permitted"
        "quote_attributed_permitted"
        "prohibited"
        "undetermined"
      ]
    }
  
    enum? personal_data_class? {
      values = [
        "none"
        "pseudonymized"
        "identifiable"
        "special_category"
        "undetermined"
      ]
    }
  
    enum redaction_status?=none {
      values = ["none", "redacted"]
    }
  
    enum origin?=human_entered {
      values = ["human_entered", "imported", "ai_proposed"]
    }
  
    int? extracted_by_job_id? {
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
      type : "btree|unique"
      field: [{name: "source_id"}, {name: "excerpt_hash"}]
    }
    {type: "btree", field: [{name: "research_project_id"}]}
    {type: "btree", field: [{name: "organization_id"}]}
  ]

  guid = "4cm0DRLQfscHuF2JBie9UUNzqmM"
}
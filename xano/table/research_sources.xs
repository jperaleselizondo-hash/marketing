table research_sources {
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
  
    enum source_kind {
      values = [
        "public_web"
        "interview"
        "survey"
        "customer_document"
        "competitor_asset"
        "import"
        "owner_attestation"
      ]
    }
  
    text? canonical_url?
    text title filters=trim
    text? publisher?
    text? author_ref?
    timestamp? published_at?
    timestamp captured_at
    text language_code filters=trim|lower
    text? content_text?
    text? content_hash?
    text? storage_ref?
    text dedupe_key
    enum retrieval_status?=ok {
      values = ["ok", "failed", "gone", "not_applicable"]
    }
  
    enum review_status?=candidate {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    text? processing_basis_code?
    text? processing_basis_jurisdiction?
    enum processing_basis_status?=undetermined {
      values = ["not_applicable", "undetermined", "proposed", "legally_reviewed"]
    }
  
    int? processing_basis_reviewed_by? {
      table = "user"
    }
  
    timestamp? processing_basis_reviewed_at?
    text? privacy_policy_version?
    enum acquisition_method {
      values = [
        "manual_capture"
        "owner_upload"
        "interview_record"
        "survey_export"
        "crm_export"
        "spreadsheet_import"
        "automated_fetch"
      ]
    }
  
    enum access_conditions {
      values = [
        "public_no_login"
        "login_required"
        "paywalled"
        "privately_shared"
      ]
    }
  
    int acquired_by {
      table = "user"
    }
  
    text? terms_note?
    enum usage_rights?=undetermined {
      values = [
        "internal_analysis_only"
        "paraphrase_permitted"
        "quote_anonymized_permitted"
        "quote_attributed_permitted"
        "prohibited"
        "undetermined"
      ]
    }
  
    text? usage_rights_basis?
    text? license_ref?
    enum personal_data_class?=undetermined {
      values = [
        "none"
        "pseudonymized"
        "identifiable"
        "special_category"
        "undetermined"
      ]
    }
  
    text? retention_rule_code?
    date? retention_until?
    enum deletion_status?=active {
      values = ["active", "scheduled", "redacted", "tombstoned"]
    }
  
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
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "research_project_id"}, {name: "dedupe_key"}]
    }
    {type: "btree", field: [{name: "organization_id"}]}
    {
      type : "btree"
      field: [{name: "research_project_id"}, {name: "review_status"}]
    }
  ]

  guid = "xXa0e46xhSVbCFbq-nM8zGprycU"
}
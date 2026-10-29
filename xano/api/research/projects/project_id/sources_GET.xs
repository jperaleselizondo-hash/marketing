query "projects/{project_id}/sources" verb=GET {
  api_group = "research"
  auth = "user"

  input {
    int project_id
    enum? review_status? {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    enum? source_kind? {
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
  
    int page?=1 filters=min:1
    int per_page?=50 filters=min:1|max:200
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "viewer"
      }
    } as $pc
  
    db.query research_sources {
      where = $db.research_sources.research_project_id == $input.project_id && $db.research_sources.review_status ==? $input.review_status && $db.research_sources.source_kind ==? $input.source_kind
      sort = {id: "asc"}
      return = {
        type  : "list"
        paging: {
          page    : $input.page
          per_page: $input.per_page
          totals  : true
        }
      }
    } as $sources
  }

  response = $sources
  guid = "vnbZ25UWe6c3pltci-uWleG7nTA"
}
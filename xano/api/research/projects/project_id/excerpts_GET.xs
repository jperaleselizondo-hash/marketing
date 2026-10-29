query "projects/{project_id}/excerpts" verb=GET {
  api_group = "research"
  auth = "user"

  input {
    int project_id
    int? source_id?
    enum? verification_status? {
      values = ["pending", "verified", "failed", "pending_human"]
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
  
    db.query source_excerpts {
      where = $db.source_excerpts.research_project_id == $input.project_id && $db.source_excerpts.source_id ==? $input.source_id && $db.source_excerpts.verification_status ==? $input.verification_status
      sort = {id: "asc"}
      return = {
        type  : "list"
        paging: {
          page    : $input.page
          per_page: $input.per_page
          totals  : true
        }
      }
    } as $excerpts
  }

  response = $excerpts
  guid = "LFeLXfBhRWnhIpxBdPzA0Oi8rco"
}
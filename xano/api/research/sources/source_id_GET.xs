query "sources/{source_id}" verb=GET {
  api_group = "research"
  auth = "user"

  input {
    int source_id
  }

  stack {
    db.get research_sources {
      field_name = "id"
      field_value = $input.source_id
    } as $source
  
    precondition ($source != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Source not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $source.research_project_id
        min_role  : "viewer"
      }
    } as $pc
  
    db.query source_excerpts {
      where = $db.source_excerpts.source_id == $source.id
      sort = {id: "asc"}
      return = {type: "list"}
    } as $excerpts
  }

  response = {source: $source, excerpts: $excerpts}
  guid = "lvgNmkr94ajGrif3bqZehNlekUA"
}
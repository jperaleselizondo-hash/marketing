query "jobs/{job_id}" verb=GET {
  api_group = "workflow"
  auth = "user"

  input {
    int job_id
  }

  stack {
    db.get jobs {
      field_name = "id"
      field_value = $input.job_id
    } as $job
  
    precondition ($job != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Job not found"
    }
  
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $job.organization_id
        min_role       : "viewer"
      }
    } as $ctx
  }

  response = $job
  guid = "vlzu2gng8aIa6FcLmvpLEL0JQgk"
}
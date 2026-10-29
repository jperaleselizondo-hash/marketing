// Append-only audit trail for an organization, newest first.
query "organizations/{organization_id}/review-events" verb=GET {
  api_group = "organizations"
  auth = "user"

  input {
    int organization_id
    int? research_project_id?
    text? entity_type?
    int? entity_id?
    int page?=1 filters=min:1
    int per_page?=50 filters=min:1|max:200
  }

  stack {
    function.run "auth/org_context" {
      input = {
        user_id        : $auth.id
        organization_id: $input.organization_id
        min_role       : "viewer"
      }
    } as $ctx
  
    db.query review_events {
      where = $db.review_events.organization_id == $input.organization_id && $db.review_events.research_project_id ==? $input.research_project_id && $db.review_events.entity_type ==? $input.entity_type && $db.review_events.entity_id ==? $input.entity_id
      sort = {id: "desc"}
      return = {
        type  : "list"
        paging: {
          page    : $input.page
          per_page: $input.per_page
          totals  : true
        }
      }
    } as $events
  }

  response = $events
  guid = "q_cPlCBtdDSkS9iCFNYanjfMGmo"
}
query "projects/{project_id}/competitor-observations" verb=GET {
  api_group = "competitors"
  auth = "user"

  input {
    int project_id
    int? competitor_id?
    enum? dimension? {
      values = [
        "idea"
        "usp"
        "pain_focus"
        "desire_focus"
        "social_media"
        "ads"
        "praise"
        "complaint"
      ]
    }
  }

  stack {
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $input.project_id
        min_role  : "viewer"
      }
    } as $pc
  
    db.query competitor_observations {
      where = $db.competitor_observations.research_project_id == $input.project_id && $db.competitor_observations.competitor_id ==? $input.competitor_id && $db.competitor_observations.dimension ==? $input.dimension
      sort = {created_at: "asc"}
      return = {type: "list"}
    } as $observations
  }

  response = $observations
  guid = "3y63ScoZL1q-V-CS5kdWEujYwPo"
}
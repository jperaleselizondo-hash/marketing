query "projects/{project_id}/assessments" verb=GET {
  api_group = "synthesis"
  auth = "user"

  input {
    int project_id
    int? research_segment_id?
    enum? assessment_type? {
      values = [
        "awareness"
        "sophistication"
        "ideal_client"
        "trust"
        "market_context"
        "competitive_summary"
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
  
    db.query research_assessments {
      where = $db.research_assessments.research_project_id == $input.project_id && $db.research_assessments.research_segment_id ==? $input.research_segment_id && $db.research_assessments.assessment_type ==? $input.assessment_type
      sort = {id: "asc"}
      return = {type: "list"}
    } as $assessments
  }

  response = $assessments
  guid = "rVseDaiYac6bRDlTPSmM3h2lusg"
}
query "projects/{project_id}/insights" verb=GET {
  api_group = "synthesis"
  auth = "user"

  input {
    int project_id
    int? research_segment_id?
    enum? status? {
      values = ["candidate", "in_review", "approved", "rejected"]
    }
  
    enum? insight_kind? {
      values = ["ivoc_theme", "opportunity"]
    }
  
    enum? ivoc_category? {
      values = [
        "pain_fear"
        "desire"
        "objection"
        "firm_belief"
        "shakable_belief"
        "vocabulary"
        "other"
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
  
    db.query research_insights {
      where = $db.research_insights.research_project_id == $input.project_id && $db.research_insights.research_segment_id ==? $input.research_segment_id && $db.research_insights.status ==? $input.status && $db.research_insights.insight_kind ==? $input.insight_kind && $db.research_insights.ivoc_category ==? $input.ivoc_category
      sort = {created_at: "desc"}
      return = {type: "list"}
    } as $insights
  }

  response = $insights
  guid = "f5aV766hdeO-5AkIZB-iZTeALNc"
}